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

import 'package:logging/logging.dart';
import 'package:pedantic/pedantic.dart';
import 'package:sponge_client_dart/sponge_client_dart.dart';
import 'package:sponge_flutter_api/src/common/bloc/connection_state.dart';
import 'package:sponge_flutter_api/src/common/bloc/forwarding_bloc.dart';
import 'package:sponge_flutter_api/src/common/configuration/connections_configuration.dart';
import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/common/service/sponge_service.dart';
import 'package:sponge_flutter_api/src/common/sponge_service_constants.dart';

enum ActionIconsView { custom, internal, none }
enum ActionsOrder { defaultOrder, alphabetical }

abstract class ApplicationSettings {
  ActionIconsView get actionIconsView;
  ActionsOrder get actionsOrder;
  bool get autoUseAuthToken;
  int maxEventCount;
  String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  int defaultPageableListPageSize = 20;
  bool get showNewEventNotification;

  Future<void> clear();
}

abstract class ApplicationService<S extends SpongeService,
    T extends ApplicationSettings> {
  static final Logger _logger = Logger('ApplicationService');

  ConnectionsConfiguration _connectionsConfiguration;
  S _spongeService;
  TypeConverter _typeConverter;
  FeatureConverter _featureConverter;
  T settings;

  final connectionBloc = ForwardingBloc<SpongeConnectionState>(
      initialValue: SpongeConnectionStateNotConnected());

  ConnectionsConfiguration get connectionsConfiguration =>
      _connectionsConfiguration;
  S get spongeService => _spongeService;

  bool get connected =>
      _spongeService != null &&
      _spongeService.connected &&
      connectionBloc.state is SpongeConnectionStateConnected;

  bool get logged =>
      connected && _spongeService.client.configuration.username != null;

  Future<void> configure(
    ConnectionsConfiguration connectionsConfiguration,
    TypeConverter typeConverter,
    FeatureConverter featureConverter, {
    bool connectSynchronously = true,
  }) async {
    _connectionsConfiguration = connectionsConfiguration;
    _typeConverter = typeConverter;
    _featureConverter = featureConverter;

    await _connectionsConfiguration.init();
    await updateDefaultConnections();

    try {
      var activeConnectionName =
          _connectionsConfiguration.getActiveConnectionName();
      if (activeConnectionName != null) {
        await _setupActiveConnection(activeConnectionName,
            connectSynchronously: connectSynchronously);
      }
    } catch (e) {
      // Only log the error thrown while setting the active connection.
      _logger.severe('Setup active connection error', e, StackTrace.current);
    }
  }

  Future<void> updateDefaultConnections() async {
    var existsDemoService = _connectionsConfiguration.getConnections().any(
        (c) =>
            c.name == SpongeServiceConstants.DEMO_SERVICE_NAME ||
            c.url == SpongeServiceConstants.DEMO_SERVICE_ADDRESS);
    if (!existsDemoService) {
      await _connectionsConfiguration.addConnection(SpongeConnection(
          name: SpongeServiceConstants.DEMO_SERVICE_NAME,
          url: SpongeServiceConstants.DEMO_SERVICE_ADDRESS,
          anonymous: true));
    }
  }

  Future<void> _connect(SpongeConnection connection) async {
    connectionBloc.add(SpongeConnectionStateConnecting());

    // Connect may be called concurrently.
    var newSpongeService = await createSpongeService(
      connection,
      _typeConverter,
      _featureConverter,
    );
    var prevSpongeService = _spongeService;
    _spongeService = newSpongeService;

    try {
      unawaited(prevSpongeService?.close());

      await configureSpongeService(newSpongeService);
      await newSpongeService.open();
      await startSpongeService(newSpongeService);

      if (identical(_spongeService, newSpongeService)) {
        connectionBloc.add(SpongeConnectionStateConnected());
      }
    } catch (e) {
      if (identical(_spongeService, newSpongeService)) {
        connectionBloc.add(SpongeConnectionStateError(e));
        rethrow;
      }
    }
  }

  Future<void> _setupActiveConnection(String connectionName,
      {bool connectSynchronously = true, bool forceRefresh = false}) async {
    if (connectionName != null) {
      var connection = _connectionsConfiguration.getConnection(connectionName);

      SpongeConnection prevConnection = _spongeService?.connection;
      if (connection != null &&
          (prevConnection == null ||
              !connection.isSame(prevConnection) ||
              forceRefresh)) {
        if (connectSynchronously) {
          await _connect(connection);
        } else {
          unawaited(_connect(connection));
        }
      }
    } else {
      await closeSpongeService();
      _spongeService = null;
      connectionBloc.add(SpongeConnectionStateNotConnected());
    }
  }

  Future<void> closeSpongeService() async {
    await _spongeService?.close();
  }

  Future<S> createSpongeService(
    SpongeConnection connection,
    TypeConverter typeConverter,
    FeatureConverter featureConverter,
  ) async =>
      SpongeService(
        connection,
        typeConverter: typeConverter,
        featureConverter: featureConverter,
      ) as S;

  Future<void> configureSpongeService(S spongeService) async {
    spongeService.maxEventCount = settings.maxEventCount;
    spongeService.autoUseAuthToken = settings.autoUseAuthToken;
  }

  Future<void> startSpongeService(S spongeService) async {}

  bool isConnectionActive(String connectionName) =>
      _connectionsConfiguration
          .getConnection(_connectionsConfiguration.getActiveConnectionName())
          ?.name ==
      connectionName;

  List<String> getAllConnectionNames() => _connectionsConfiguration
      .getConnections()
      .map((connection) => connection.name)
      .toList();

  bool get hasConnections => _connectionsConfiguration.hasConnections;

  Future<void> setActiveConnection(String connectionName,
      {bool connectSynchronously = true, bool forceRefresh = false}) async {
    await _connectionsConfiguration.setActiveConnection(connectionName);
    await _setupActiveConnection(connectionName,
        connectSynchronously: connectSynchronously, forceRefresh: forceRefresh);
  }

  Future<void> clearSettings() async {
    await settings?.clear();
  }

  Future<void> clearConnections() async {
    await _connectionsConfiguration.clearConnections();
    await updateDefaultConnections();
    await setActiveConnection(null);
    connectionBloc.add(SpongeConnectionStateNotConnected());
  }

  Future<void> setConnections(
      List<SpongeConnection> connections, String activeConnectionName) async {
    await _connectionsConfiguration.clearConnections();

    await for (var c in Stream.fromIterable(connections)) {
      await _connectionsConfiguration.addConnection(c);
    }

    await setActiveConnection(activeConnectionName);
  }

  SpongeConnection get activeConnection => _connectionsConfiguration
      .getConnection(_connectionsConfiguration.getActiveConnectionName());

  Future<void> changeActiveConnectionCredentials(
      String username, String password, bool anonymous,
      {bool savePassword}) async {
    var connection = activeConnection;
    connection
      ..username = username
      ..password = password
      ..anonymous = anonymous;

    if (savePassword != null) {
      connection.savePassword = savePassword;
    }

    await _connectionsConfiguration.updateConnection(connection);

    _spongeService.connection.setFrom(connection);

    _spongeService.client.configuration
      ..username = connection.anonymous ? null : connection.username
      ..password = connection.anonymous ? null : connection.password;

    await _spongeService.client.clearSession();
  }

  Future<void> changeActiveConnectionSubscription(
      List<String> eventNames, bool subscribe) async {
    var connection = activeConnection;
    connection.subscribe = subscribe;
    connection.subscriptionEventNames = eventNames;
    await _connectionsConfiguration.updateConnection(connection);

    _spongeService.connection.setFrom(connection);
  }

  Future<void> clearEventNotifications() async {}
}
