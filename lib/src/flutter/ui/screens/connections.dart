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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:modal_progress_hud/modal_progress_hud.dart';
import 'package:provider/provider.dart';
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/common/ui/connections_mvp.dart';
import 'package:sponge_flutter_api/src/flutter/application_provider.dart';
import 'package:sponge_flutter_api/src/flutter/service/flutter_application_service.dart';
import 'package:sponge_flutter_api/src/flutter/ui/screens/connection_edit.dart';
import 'package:sponge_flutter_api/src/flutter/ui/util/utils.dart';
import 'package:sponge_flutter_api/src/flutter/ui/widgets/dialogs.dart';
import 'package:sponge_flutter_api/src/flutter/widget_factory.dart';
import 'package:sponge_flutter_api/src/util/utils.dart';

class ConnectionsPage extends StatefulWidget {
  ConnectionsPage({
    Key key,
    this.onGetNetworkName,
  }) : super(key: key);

  final AsyncValueGetter<String> onGetNetworkName;

  @override
  createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage>
    implements ConnectionsView {
  ConnectionsPresenter _presenter;

  @override
  void initState() {
    super.initState();

    _presenter = ConnectionsPresenter(ConnectionsViewModel(), this);
  }

  @override
  void dispose() {
    _presenter.unbound();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _presenter
      ..setService(ApplicationProvider.of(context).service)
      ..refreshModel();

    return Scaffold(
      appBar: AppBar(
        title: Text('Connections'),
        actions: _buildMenu(context),
      ),
      body: SafeArea(
        child: ModalProgressHUD(
          child: _buildWidget(),
          inAsyncCall: _presenter.busy,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _addConnection().catchError((e) => handleError(context, e)),
        tooltip: 'Add',
        child: Icon(Icons.add),
        backgroundColor: getFloatingButtonBackgroudColor(context),
      ),
    );
  }

  Widget _buildWidget() {
    var service = _presenter.service as FlutterApplicationService;

    return FutureBuilder<String>(
      future:
          widget.onGetNetworkName != null ? widget.onGetNetworkName() : null,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        List<SpongeConnection> connections = snapshot.hasData
            ? _presenter.getFilteredConnections(
                widget.onGetNetworkName != null &&
                    service.settings.filterConnectionsByNetwork,
                widget.onGetNetworkName != null ? snapshot.data : null)
            : _presenter.connections;

        return ListView.builder(
          padding: const EdgeInsets.all(4.0),
          itemBuilder: (context, i) => _buildRow(context, connections[i]),
          itemCount: connections.length,
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, SpongeConnection connection) {
    return Dismissible(
      key: Key(connection.name),
      child: Card(
        child: ListTile(
          leading: _presenter.isConnectionActive(connection.name)
              ? Icon(
                  Icons.check,
                  color: getIconColor(context),
                )
              : null,
          trailing: GestureDetector(
            child: Icon(Icons.edit, color: getIconColor(context)),
            onTap: () => _editConnection(context, connection)
                .catchError((e) => handleError(context, e)),
          ),
          title: Text(connection.name),
          subtitle:
              connection.network != null ? Text(connection.network) : null,
          onTap: () => _toggleActiveConnection(connection)
              .catchError((e) => handleError(context, e)),
        ),
      ),
      confirmDismiss: (_) async {
        setState(() => _presenter.busy = true);
        return true;
      },
      onDismissed: (direction) => _removeConnection(context, connection.name)
          .catchError((e) => handleError(context, e)),
    );
  }

  List<Widget> _buildMenu(BuildContext context) {
    var customItems = Provider.of<SpongeWidgetsFactory>(context)
        .createConnectionsPageMenuItems(context);

    var service = _presenter.service as FlutterApplicationService;

    return <Widget>[
      PopupMenuButton<String>(
        key: Key('connections-menu'),
        onSelected: (value) async {
          var customOnSelected = customItems
              .firstWhere((config) => config.value == value, orElse: () => null)
              ?.onSelected;
          if (customOnSelected != null) {
            customOnSelected(_presenter);
          } else {
            switch (value) {
              case 'filterByNetwork':
                await service.settings.setFilterConnectionsByNetwork(
                    !service.settings.filterConnectionsByNetwork);
                setState(() {});
                break;
              case 'updateDefaultConnections':
                setState(() => _presenter.busy = true);
                try {
                  await _presenter.service.updateDefaultConnections();
                } finally {
                  setState(() => _presenter.busy = false);
                }
                break;
              case 'clearConnections':
                await _clearConnections();
                break;
            }
          }
        },
        itemBuilder: (BuildContext context) => [
          ...customItems
              .map((config) => config.itemBuilder(_presenter, context))
              .toList(),
          if (customItems.isNotEmpty) PopupMenuDivider(),
          if (widget.onGetNetworkName != null)
            PopupMenuItem<String>(
              key: Key('filterByNetwork'),
              value: 'filterByNetwork',
              child: IconTextPopupMenuItemWidget(
                icon: Icons.filter_list,
                text: 'Filter by network',
                isOn: service.settings.filterConnectionsByNetwork,
              ),
            ),
          PopupMenuItem<String>(
            key: Key('updateDefaultConnections'),
            value: 'updateDefaultConnections',
            child: IconTextPopupMenuItemWidget(
              icon: Icons.update,
              text: 'Update default services',
            ),
          ),
          PopupMenuItem<String>(
            key: Key('clearConnections'),
            value: 'clearConnections',
            child: IconTextPopupMenuItemWidget(
              icon: Icons.clear_all,
              text: 'Clear connections',
            ),
          ),
        ],
        padding: EdgeInsets.zero,
      )
    ];
  }

  _toggleActiveConnection(SpongeConnection connection) async {
    setState(() {
      _presenter.busy = true;
    });

    try {
      await _presenter.toggleActiveConnection(connection);

      ApplicationProvider.of(context)
          .updateConnection(connection, refresh: false);
    } finally {
      setState(() {
        _presenter.busy = false;
      });
    }
  }

  _addConnection() async {
    setState(() {
      _presenter.busy = true;
    });

    try {
      await _presenter.showAddConnection();
    } finally {
      setState(() {
        _presenter.busy = false;
      });
    }
  }

  _editConnection(
      BuildContext context, SpongeConnection editedConnection) async {
    SpongeConnection newConnection;

    setState(() => _presenter.busy = true);
    try {
      newConnection = await _presenter.showEditConnection(editedConnection);
    } finally {
      setState(() => _presenter.busy = false);
    }

    if (newConnection != null &&
        _presenter.isConnectionActive(newConnection.name)) {
      ApplicationProvider.of(context).updateConnection(newConnection);
    }
  }

  _removeConnection(BuildContext context, String name) async {
    try {
      await _presenter.removeConnection(name);
    } finally {
      setState(() => _presenter.busy = false);
    }
  }

  Future<SpongeConnection> addConnection() async => await Navigator.push(
        context,
        MaterialPageRoute<SpongeConnection>(
          builder: (context) => ConnectionEditPage(),
        ),
      );

  Future<SpongeConnection> editConnection(SpongeConnection connection) async {
    return await Navigator.push(
      context,
      MaterialPageRoute<SpongeConnection>(
        builder: (context) =>
            ConnectionEditPage(originalConnection: connection),
      ),
    );
  }

  @override
  void refresh([OnRefreshCallback callback]) {
    setState(() {
      if (callback != null) {
        callback();
      }
    });
  }

  Future<void> _clearConnections() async {
    if (!await showConfirmationDialog(
        context, 'Do you want to remove the connections?')) {
      return;
    }

    setState(() => _presenter.busy = true);
    try {
      await _presenter.service.clearConnections();
    } finally {
      setState(() => _presenter.busy = false);
    }
  }
}
