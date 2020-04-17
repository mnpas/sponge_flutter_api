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

import 'package:flutter/widgets.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';

class ModelUtils {
  static String getActionMetaDisplayLabel(ActionMeta actionMeta) =>
      actionMeta.label ?? actionMeta.name;

  static String getSafeTypeDisplayLabel(DataType type) =>
      type.label ?? type.name;

  static String getActionGroupDisplayLabel(ActionMeta actionMeta) =>
      actionMeta.category?.label ??
      actionMeta.category?.name ??
      actionMeta.knowledgeBase?.label ??
      actionMeta.knowledgeBase?.name;

  /// Returns the qualified action label (category or knowledge base: action).
  static String getQualifiedActionDisplayLabel(ActionMeta actionMeta) {
    return '${getActionGroupDisplayLabel(actionMeta)}: ${getActionMetaDisplayLabel(actionMeta)}';
  }

  /// Returns `null` if not found.
  static DataType getActionArgByIntent(
          ActionMeta actionMeta, String intentValue) =>
      actionMeta.args.firstWhere(
          (arg) =>
              arg.features[Features.INTENT] == intentValue ||
              arg.name == intentValue,
          orElse: () => null);

  static List<dynamic> substituteSubActionArgs(
    SpongeService spongeService,
    SubActionSpec subActionSpec,
    DataType sourceType,
    dynamic sourceValue, {
    @required bool propagateContextActions,
    bool bestEffort = false,
  }) {
    ActionMeta subActionMeta =
        spongeService.getCachedAction(subActionSpec.actionName).actionMeta;
    var subActionData = ActionData(subActionMeta);

    bool showActionCallWidget = subActionMeta.args.length >
        (subActionSpec.argSubstitutions?.length ?? 1);

    if (subActionSpec.argSubstitutions == null) {
      // The default behavior that sets the first arg of the sub-action, if any.
      if (subActionMeta.args.isNotEmpty) {
        try {
          // TODO More strict sub-action arg validation.
          Validate.isTrue(subActionMeta.args[0].kind == sourceType.kind,
              'The first argument of ${subActionMeta.name} action should be ${sourceType.kind}');
          subActionData.args[0] = DataTypeUtils.cloneValue(sourceValue);
        } catch (e) {
          if (!bestEffort) {
            rethrow;
          }
        }
      }
    } else {
      for (var i = 0; i < subActionData.args.length; i++) {
        var subArgType = subActionMeta.args[i];

        var subActionArgSpec = subActionSpec.argSubstitutions.firstWhere(
            (substitution) => substitution.target == subArgType.name,
            orElse: () => null);
        if (subActionArgSpec != null) {
          try {
            subActionData.args[i] = DataTypeUtils.cloneValue(
                DataTypeUtils.getSubValue(sourceValue, subActionArgSpec.source,
                    unwrapAnnotatedTarget: false, unwrapDynamicTarget: false));
          } catch (e) {
            if (!bestEffort) {
              rethrow;
            }
          }
        }
      }
    }

    if (!bestEffort) {
      for (var i = 0; i < subActionData.args.length; i++) {
        var subArgType = subActionMeta.args[i];

        var subActionArgSpec = subActionSpec.argSubstitutions?.firstWhere(
            (substitution) => substitution.target == subArgType.name,
            orElse: () => null);

        Validate.isTrue(
            Features.getOptional(
                        subArgType.features, Features.VISIBLE, () => true) &&
                    showActionCallWidget ||
                subArgType.nullable ||
                DataTypeUtils.hasAllNotNullValuesSet(
                    subArgType, subActionData.args[i]),
            // TODO Support context actions in dynamic types.
            subActionArgSpec != null
                ? 'The argument \'${getSafeTypeDisplayLabel(DataTypeUtils.getSubType(sourceType, subActionArgSpec.source, null))}\' is not set properly'
                : 'The sub-action argument \'${getSafeTypeDisplayLabel(subArgType)}\' is not set properly');
      }
    }

    // Do not propagate context actions to sub-actions.
    subActionData.args = subActionData.args.map((arg) {
      if (arg is AnnotatedValue && !propagateContextActions) {
        arg = AnnotatedValue.of(arg)
          ..features
              .removeWhere((name, value) => name == Features.CONTEXT_ACTIONS);
      }

      return arg;
    }).toList();

    return subActionData.args;
  }

  static RootRecordSingleLeadingField getRootRecordSingleLeadingFieldByAction(
      ActionData actionData) {
    var recordType = actionData.argsAsRecordType;
    var rootRecordSingleLeadingField = getRootRecordSingleLeadingField(
        QualifiedDataType(recordType), actionData.argsAsRecord);

    if (rootRecordSingleLeadingField != null) {
      // If the action has buttons, it cannot have the record single leading field.
      var actionMeta = actionData.actionMeta;
      if (actionMeta.callable && showCall(actionMeta) ||
          showRefresh(actionMeta) ||
          showClear(actionMeta) ||
          showCancel(actionMeta)) {
        return null;
      }
    }

    return rootRecordSingleLeadingField;
  }

  static RootRecordSingleLeadingField getRootRecordSingleLeadingField(
      QualifiedDataType qualifiedRecordType, Map recordValue) {
    if (!(qualifiedRecordType.type is RecordType)) {
      return null;
    }

    var recordType = qualifiedRecordType.type as RecordType;

    if (qualifiedRecordType.isRoot && recordType.fields.length == 1) {
      var fieldType = recordType.fields[0];
      var fieldValue = recordValue[fieldType.name];
      var fieldFeatures = DataTypeUtils.mergeFeatures(fieldType, fieldValue);

      // TODO Better check for the RootRecordSingleLeadingField.
      if (fieldFeatures[Features.GEO_MAP] != null) {
        return RootRecordSingleLeadingField(
            qualifiedRecordType.createChild(fieldType),
            fieldValue,
            fieldFeatures);
      }
    }

    return null;
  }

  static bool showCall(ActionMeta actionMeta) => Features.getOptional(
      actionMeta.features, Features.ACTION_CALL_SHOW_CALL, () => true);

  static bool showRefresh(ActionMeta actionMeta) => Features.getOptional(
      actionMeta.features,
      Features.ACTION_CALL_SHOW_REFRESH,
      () => actionMeta.features[Features.ACTION_CALL_REFRESH_LABEL] != null);

  static bool showClear(ActionMeta actionMeta) => Features.getOptional(
      actionMeta.features,
      Features.ACTION_CALL_SHOW_CLEAR,
      () => actionMeta.features[Features.ACTION_CALL_CLEAR_LABEL] != null);

  static bool showCancel(ActionMeta actionMeta) => Features.getOptional(
      actionMeta.features,
      Features.ACTION_CALL_SHOW_CANCEL,
      () => actionMeta.features[Features.ACTION_CALL_CANCEL_LABEL] != null);

  static String getValueLabel(dynamic value) =>
      (value != null && value is AnnotatedValue) ? value.valueLabel : null;

  static String getValueDescription(dynamic value) =>
      (value != null && value is AnnotatedValue)
          ? value.valueDescription
          : null;

  static String substring(String s, int maxLength) =>
      s != null && s.length > maxLength
          ? s.substring(0, maxLength).trim() + '...'
          : s;

  static bool shouldConnectionBeFiltered(
      SpongeConnection connection, NetworkStatus networkStatus) {
    return connection.network == null ||
        connection.network.isEmpty ||
        networkStatus == null ||
        connection.network?.toLowerCase() == networkStatus.name?.toLowerCase();
  }
}
