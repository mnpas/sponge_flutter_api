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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:modal_progress_hud/modal_progress_hud.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/connection_state.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';
import 'package:sponge_flutter_api/src/common/ui/actions_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/state_container.dart';
import 'package:sponge_flutter_api/src/flutter/ui/screens/action_call.dart';
import 'package:sponge_flutter_api/src/flutter/ui/screens/action_list_item.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/drawer.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/error_widgets.dart';
import 'package:sponge_flutter_api/src/util/utils.dart';

class ActionsWidget extends StatefulWidget {
  ActionsWidget({Key key}) : super(key: key);

  @override
  _ActionsWidgetState createState() => _ActionsWidgetState();
}

class _ActionGroup {
  _ActionGroup(this.name, this.actions);

  final String name;
  final List<ActionData> actions;
}

class _ActionsWidgetState extends State<ActionsWidget>
    with TickerProviderStateMixin
    implements ActionsView {
  ActionsPresenter _presenter;
  int _initialTabIndex = 0;
  bool _useTabs;
  bool _busyNoConnection = false;

  String _lastConnectionName;

  Future<List<_ActionGroup>> _getActionGroups() async {
    var allActions = await _presenter.getActions();

    Map<String, List<ActionData>> groupMap = {};
    allActions.forEach((action) =>
        (groupMap[getActionGroupDisplayLabel(action.actionMeta)] ??= [])
            .add(action));

    var actionGroups = groupMap.entries
        .map((entry) => _ActionGroup(entry.key, entry.value))
        .toList();
    return actionGroups;
  }

  bool _isDone(AsyncSnapshot<List<_ActionGroup>> snapshot) =>
      snapshot.connectionState == ConnectionState.done && snapshot.hasData;

  @override
  Widget build(BuildContext context) {
    var service = StateContainer.of(context).service;
    _presenter ??= ActionsPresenter(this);

    service.bindMainBuildContext(context);

    this._presenter.setService(service);

    return WillPopScope(
      child: StreamBuilder(
          stream: service.connectionBloc,
          initialData: service.connectionBloc.state,
          builder: (BuildContext context,
              AsyncSnapshot<SpongeConnectionState> snapshot) {
            if (snapshot.hasData) {
              if (snapshot.data is SpongeConnectionStateNotConnected) {
                return _buildScaffold(
                  context,
                  child: ConnectionNotInitializedWidget(
                      hasConnections: _presenter.hasConnections),
                );
              } else if (snapshot.data is SpongeConnectionStateConnecting) {
                return _buildScaffold(
                  context,
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.data is SpongeConnectionStateError) {
                return _buildScaffold(
                  context,
                  child: Center(
                    child: ErrorPanelWidget(
                      error:
                          (snapshot.data as SpongeConnectionStateError).error,
                    ),
                  ),
                );
              } else {
                return FutureBuilder<List<_ActionGroup>>(
                  future:
                      _busyNoConnection ? Future(() => []) : _getActionGroups(),
                  builder: (context, snapshot) {
                    _useTabs = service.settings.tabsInActionList &&
                        _isDone(snapshot) &&
                        snapshot.data.length > 1;

                    _lastConnectionName ??= _presenter.connectionName;
                    if (_useTabs) {
                      if (_lastConnectionName != _presenter.connectionName) {
                        _initialTabIndex = 0;
                      } else {
                        _initialTabIndex =
                            _useTabs && _initialTabIndex < snapshot.data.length
                                ? _initialTabIndex
                                : 0;
                      }
                    }

                    _lastConnectionName = _presenter.connectionName;

                    var tabBar = _useTabs
                        ? ColoredTabBar(
                            child: TabBar(
                              // TODO Parametrize tabbar scroll in settings.
                              isScrollable: snapshot.data.length > 3,
                              tabs: snapshot.data
                                  .map((group) => Tab(
                                        key: Key('group-${group.name}'),
                                        child: Tooltip(
                                          child: Text(group.name.toUpperCase()),
                                          message: group.name,
                                        ),
                                      ))
                                  .toList(),
                              onTap: (index) => _initialTabIndex = index,
                              //labelColor: getSecondaryColor(context),
                              //unselectedLabelColor: getTextColor(context),
                              indicatorColor: getSecondaryColor(context),
                            ),
                            color: getThemedBackgroundColor(context),
                          )
                        : null;

                    var scaffold = _buildScaffold(
                      context,
                      child: _presenter.connected
                          ? (_busyNoConnection
                              ? Center(child: CircularProgressIndicator())
                              : _buildActionGroupWidget(context, snapshot))
                          : ConnectionNotInitializedWidget(
                              hasConnections: _presenter.hasConnections),
                      tabBar: tabBar,
                      actionGroupsSnapshot: snapshot,
                    );

                    return _useTabs
                        ? DefaultTabController(
                            length: snapshot.data.length,
                            child: scaffold,
                            initialIndex: _initialTabIndex,
                          )
                        : scaffold;
                  },
                );
              }
            } else if (snapshot.hasError) {
              return _buildScaffold(
                context,
                child: Center(
                  child: ErrorPanelWidget(
                    error: snapshot.error,
                  ),
                ),
              );
            } else {
              return _buildScaffold(
                context,
                child: Center(child: CircularProgressIndicator()),
              );
            }
          }),
      onWillPop: () async => await showAppExitConfirmationDialog(context),
    );
  }

  Scaffold _buildScaffold(
    BuildContext context, {
    @required Widget child,
    PreferredSizeWidget tabBar,
    AsyncSnapshot<List<_ActionGroup>> actionGroupsSnapshot =
        const AsyncSnapshot.withData(ConnectionState.done, []),
  }) {
    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(context),
        actions: _buildConnectionsWidget(context),
        bottom: tabBar,
      ),
      drawer: HomeDrawer(),
      body: SafeArea(
        child: ModalProgressHUD(
          child: child,
          inAsyncCall: _presenter.busy,
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(
        context,
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Widget _buildActionGroupWidget(
      BuildContext context, AsyncSnapshot<List<_ActionGroup>> snapshot) {
    //if (_isDone(snapshot)) {
    //if (snapshot.data.length > 1) {

    bool showSimpleActionName =
        _useTabs || snapshot.hasData && snapshot.data.length == 1;

    if (_useTabs) {
      return TabBarView(
        children: snapshot.data
            .map((group) => Center(
                child: _buildActionListWidget(context, 'actions-${group.name}',
                    snapshot, group.actions, !showSimpleActionName)))
            .toList(),
      );
    } else {
      return Center(
        child: _buildActionListWidget(
            context,
            'actions',
            snapshot,
            snapshot.data != null
                ? snapshot.data.expand((group) => group.actions).toList()
                : [],
            !showSimpleActionName),
      );
    }
  }

  Widget _buildTitle(BuildContext context) {
    return Text('Actions' +
        (_presenter.connectionName != null
            ? ' (${_presenter.connectionName})'
            : ''));
  }

  Future<void> _changeConnection(BuildContext context, String name) async {
    try {
      setState(() {
        _presenter.busy = _busyNoConnection = true;
      });

      //bool isNewConnectionDifferent = true;

      try {
        await _presenter.onConnectionChange(name);

        // isNewConnectionDifferent = StateContainer.of(context)
        //     .updateConnection(_presenter.connection, refresh: false);
      } finally {
        if (mounted) {
          setState(() {
            _presenter.busy = _busyNoConnection = false;
            //if (isNewConnectionDifferent) {
            _initialTabIndex = 0;
            //}
          });
        }
      }
    } catch (e) {
      // TODO May throw an exception if the operations takes too long and meanwhile a connection has been changed.
      await handleError(context, e);
    }
  }

  List<Widget> _buildConnectionsWidget(BuildContext context) =>
      _presenter.hasConnections
          ? <Widget>[
              PopupMenuButton<String>(
                key: Key('connections'),
                onSelected: (value) => _changeConnection(context, value),
                itemBuilder: (BuildContext context) => _presenter
                    .getConnections()
                    .map((c) => CheckedPopupMenuItem<String>(
                          key: Key('connection-${c.name}'),
                          value: c.name,
                          checked: c.isActive,
                          child: Text(c.name),
                        ))
                    .toList(),
                padding: EdgeInsets.zero,
              )
            ]
          : null;

  Widget _buildFloatingActionButton(BuildContext context) =>
      _presenter.connected
          ? FloatingActionButton(
              onPressed: () => _refreshActions(context)
                  .then((_) => setState(() {}))
                  .catchError((e) => handleError(context, e)),
              tooltip: 'Refresh actions',
              child: Icon(Icons.refresh),
              backgroundColor: getFloatingButtonBackgroudColor(context),
            )
          : null;

  Future<void> _refreshActions(BuildContext context) async {
    await _presenter.refreshActions();
    StateContainer.of(context)
        .updateConnection(_presenter.connection, force: true);
  }

  Widget _buildActionListWidget(
      BuildContext context,
      String tabName,
      AsyncSnapshot<List<_ActionGroup>> snapshot,
      List<ActionData> actions,
      bool showQualifiedActionName) {
    if (snapshot.connectionState == ConnectionState.done) {
      if (snapshot.hasData) {
        return ListView.builder(
          key: PageStorageKey<String>(
              '${_presenter.connectionName}-actions-$tabName'),
          padding: const EdgeInsets.only(
              left: 4.0, right: 4.0, top: 4.0, bottom: 100.0),
          itemBuilder: (context, i) {
            var actionData = actions[i];
            return ActionListItem(
              key: Key('action-${actionData.actionMeta.name}'),
              actionData: actionData,
              onActionCall: (action) async {
                if (_useTabs) {
                  _initialTabIndex =
                      DefaultTabController.of(context)?.index ?? 0;
                }
                await _presenter.onActionCall(action);
              },
              showQualifiedName: showQualifiedActionName,
            );
          },
          itemCount: actions.length,
        );
      } else if (snapshot.hasError) {
        if (snapshot.error is UsernamePasswordNotSetException) {
          return UsernamePasswordNotSetWidget(
              connectionName: _presenter.connectionName);
        } else {
          return ErrorPanelWidget(error: snapshot.error);
        }
      }
    }

    // By default, show a loading spinner.
    return CircularProgressIndicator();
  }

  @override
  Future<bool> showActionCallConfirmationDialog(ActionData actionData) async =>
      await showConfirmationDialog(context,
          'Do you want to run ${getActionMetaDisplayLabel(actionData.actionMeta)}?');

  @override
  Future<ActionData> showActionCallScreen(ActionData actionData) async {
    return await showActionCall(
      context,
      actionData,
      builder: (context) => ActionCallWidget(
        actionData: actionData,
        bloc: _presenter.service.spongeService
            .getActionCallBloc(actionData.actionMeta.name),
      ),
    );
  }
}
