// Copyright (c) 2017 Sony Corporation. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// softmax.cu

#include <algorithm>
#include <nbla/array.hpp>
#include <nbla/cuda/common.hpp>
#include <nbla/cuda/cudnn/cudnn.hpp>
#include <nbla/cuda/cudnn/function/softmax.hpp>
#include <nbla/variable.hpp>

namespace nbla {

template <typename T>
void SoftmaxCudaCudnn<T>::setup_impl(const Variables &inputs,
                                     const Variables &outputs) {
  Softmax<T>::setup_impl(inputs, outputs);
  cudnn_handle_ = SingletonManager::get<CudnnHandleManager>()->handle(device_);
  int N = this->size0_;
  int C = this->size1_;
  int H = this->size2_;
  int W = 1;
  const int stride_w = 1;
  const int stride_h = W * stride_w;
  const int stride_c = H * stride_h;
  const int stride_n = C * stride_c;
  NBLA_CUDNN_CHECK(cudnnSetTensor4dDescriptorEx(
      input_desc_, cudnn_data_type<T>::type(), N, C, H, W, stride_n, stride_c,
      stride_h, stride_w));
  NBLA_CUDNN_CHECK(cudnnSetTensor4dDescriptorEx(
      output_desc_, cudnn_data_type<T>::type(), N, C, H, W, stride_n, stride_c,
      stride_h, stride_w));
  // default algorithm setting.
  // TODO: set by context.
  set_cudnn_softmax_algorithm("ACCURATE");
}

template <class T>
void SoftmaxCudaCudnn<T>::forward_impl(const Variables &inputs,
                                       const Variables &outputs) {
  cuda_set_device(std::stoi(this->ctx_.device_id));
  const T *x = inputs[0]->get_data_pointer<T>(this->ctx_);
  T *y = outputs[0]->cast_data_and_get_pointer<T>(this->ctx_);
  T alpha = 1;
  T beta = 0;
  NBLA_CUDNN_CHECK(cudnnSoftmaxForward(cudnn_handle_, algorithm_,
                                       CUDNN_SOFTMAX_MODE_CHANNEL, &alpha,
                                       input_desc_, x, &beta, output_desc_, y));
}

template <class T>
void SoftmaxCudaCudnn<T>::backward_impl(const Variables &inputs,
                                        const Variables &outputs,
                                        const vector<bool> &propagate_down,
                                        const vector<bool> &accum) {
  if (!propagate_down[0]) {
    return;
  }
  cuda_set_device(std::stoi(this->ctx_.device_id));
  const T *y = outputs[0]->get_data_pointer<T>(this->ctx_);
  const T *dy = outputs[0]->get_grad_pointer<T>(this->ctx_);
  T *dx = inputs[0]->cast_grad_and_get_pointer<T>(this->ctx_);
  T alpha = 1;
  T beta = accum[0] ? 1 : 0;
  NBLA_CUDNN_CHECK(cudnnSoftmaxBackward(
      cudnn_handle_, algorithm_, CUDNN_SOFTMAX_MODE_CHANNEL, &alpha,
      output_desc_, y, output_desc_, dy, &beta, input_desc_, dx));
}

template <class T>
void SoftmaxCudaCudnn<T>::set_cudnn_softmax_algorithm(std::string algorithm) {
  if (algorithm == "FAST") {
    algorithm_ = CUDNN_SOFTMAX_FAST;
  } else if (algorithm == "ACCURATE") {
    algorithm_ = CUDNN_SOFTMAX_ACCURATE;
  } else {
    NBLA_ERROR(error_code::target_specific, "Specified unsupported algorithm");
  }
}

template class SoftmaxCudaCudnn<float>;
}