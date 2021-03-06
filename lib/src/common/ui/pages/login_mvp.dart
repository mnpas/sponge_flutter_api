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

import 'package:sponge_flutter_api/src/common/model/sponge_model.dart';
import 'package:sponge_flutter_api/src/common/service/application_service.dart';
import 'package:sponge_flutter_api/src/common/ui/mvp/mvp.dart';

class LoginViewModel extends BaseViewModel {
  LoginViewModel(this.connectionName);

  final String connectionName;
}

abstract class LoginView extends BaseView {}

class LoginPresenter extends BasePresenter<LoginViewModel, LoginView> {
  LoginPresenter(
      ApplicationService service, LoginViewModel viewModel, LoginView view)
      : super(service, viewModel, view) {
    _init();
  }

  LoginData _loginData;

  String get username => _loginData.username;
  set username(String value) => _loginData.username = value;

  String get password => _loginData.password;
  set password(String value) => _loginData.password = value;

  bool get savePassword => _loginData.savePassword;
  set savePassword(bool value) => _loginData.savePassword = value;

  String get title => 'Log in to ${viewModel.connectionName}';

  LoginData get loginData => _loginData;

  void _init() {
    _loginData = LoginData(
      username: service.activeConnection.username,
      password: service.activeConnection.password,
      savePassword: service.activeConnection.savePassword ?? false,
    );
  }

  Future<void> logIn() async {
    service.activeConnection
      ..username = _loginData.username
      ..password = _loginData.password
      ..anonymous = false
      ..savePassword = _loginData.savePassword;

    await service.setActiveConnection(service.activeConnection.name,
        connectSynchronously: true, forceRefresh: true);
  }

  void onCancel() {
    service.activeConnection
      ..username = _loginData.username
      ..password = _loginData.password
      ..anonymous = false
      ..savePassword = _loginData.savePassword;
  }
}
