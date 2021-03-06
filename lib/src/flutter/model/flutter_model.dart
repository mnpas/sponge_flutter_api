// Copyright 2018 The Sponge authors.
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

import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/flutter/ui/type_gui_provider/type_gui_provider.dart';

class FlutterActionData extends ActionData {
  FlutterActionData(ActionMeta actionMeta, this.typeGuiProviderRegistry)
      : super(actionMeta) {
    _initProviders();
  }

  final TypeGuiProviderRegistry typeGuiProviderRegistry;
  Map<String, TypeGuiProvider> _argProviders;
  Map<String, TypeGuiProvider> get argProviders => _argProviders;
  TypeGuiProvider _resultProvider;
  TypeGuiProvider get resultProvider => _resultProvider;

  @override
  set args(List<Object> value) {
    super.args = value;
    _initArgProviders();
  }

  @override
  set resultInfo(ActionCallResultInfo value) {
    super.resultInfo = value;
    _initResultProvider();
  }

  void _initArgProviders() {
    _argProviders = {
      for (var argType in actionMeta.args)
        argType.name: typeGuiProviderRegistry.getProvider(argType)
    };
  }

  void _initResultProvider() {
    _resultProvider = typeGuiProviderRegistry.getProvider(actionMeta.result);
  }

  void _initProviders() {
    _initArgProviders();
    _initResultProvider();
  }

  @override
  FlutterActionData clone({ActionData prototype}) => (super.clone(
          prototype: FlutterActionData(actionMeta, typeGuiProviderRegistry))
      as FlutterActionData)
    .._initProviders();
}
