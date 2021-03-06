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
import 'package:sponge_flutter_api/src/common/bloc/action_call_bloc.dart';
import 'package:sponge_flutter_api/src/common/bloc/action_call_state.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';
import 'package:sponge_flutter_api/src/common/util/model_utils.dart';

typedef OnActionCallCalllback = Future<void> Function(ActionData actionData);

class ActionListItemViewModel extends BaseViewModel {
  ActionListItemViewModel(this.actionData, this.onActionCall);
  final ActionData actionData;
  final OnActionCallCalllback onActionCall;
}

abstract class ActionListItemView extends BaseView {}

class ActionListItemPresenter
    extends BasePresenter<ActionListItemViewModel, ActionListItemView> {
  ActionListItemPresenter(ApplicationService service,
      ActionListItemViewModel model, ActionListItemView view)
      : super(service, model, view);

  ActionCallState state = ActionCallStateInitialize();

  ActionData get actionData => viewModel.actionData;
  ActionMeta get actionMeta => actionData.actionMeta;

  ActionCallBloc get bloc =>
      service.spongeService.getActionCallBloc(actionMeta.name);

  String get label => ModelUtils.getActionMetaDisplayLabel(actionMeta);

  String get qualifiedLabel =>
      ModelUtils.getQualifiedActionDisplayLabel(actionMeta);

  String get tooltip =>
      actionMeta.description ?? actionMeta.label ?? actionMeta.name;

  bool get isInstantActionCallAllowed =>
      actionMeta.args != null &&
      actionMeta.args.isEmpty &&
      (actionMeta.callable ?? true);

  bool get isEffectivelyCallable =>
      actionMeta.callable || (actionMeta.args?.isNotEmpty ?? false);

  String get resultLabel => actionMeta.result?.label ?? 'Result';

  Future<void> onActionCall() async {
    if (!(state is ActionCallStateCalling) &&
        !actionData.calling &&
        isEffectivelyCallable) {
      await viewModel.onActionCall(actionData);
    }
  }
}
