// Copyright 2020 The Sponge authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:meta/meta.dart';

class ProvideActionArgsState {
  ProvideActionArgsState({
    @required List<String> loading,
  }) : loading = loading ?? [];

  final List<String> loading;
}

class ProvideActionArgsStateInitialize extends ProvideActionArgsState {}

class ProvideActionArgsStateBeforeInvocation extends ProvideActionArgsState {
  ProvideActionArgsStateBeforeInvocation({
    @required List<String> loading,
    this.initial = false,
  }) : super(loading: loading);

  final bool initial;
}

class ProvideActionArgsStateAfterInvocation extends ProvideActionArgsState {}

class ProvideActionArgsStateNoInvocation extends ProvideActionArgsState {}

class ProvideActionArgsStateError extends ProvideActionArgsState {
  ProvideActionArgsStateError(this.error);

  final dynamic error;
}
