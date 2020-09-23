import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:lite_rolling_switch/lite_rolling_switch.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft,DeviceOrientation.landscapeRight]);
    return MaterialApp(
      title: 'Bluetooth Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.amber),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection connection;
  int _deviceState;
  bool get isConnected => connection != null && connection.isConnected;
  List<BluetoothDevice> _devicesList = [];
  bool _isButtonUnavailable = true;
  bool _connected = false;
  BluetoothDevice _device;
  @override
  void initState() {
    super.initState();
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });
    _deviceState = 0;
    enableBluetooth();
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState bluetoothState) {
      setState(() {
        _bluetoothState = bluetoothState;
        getPairedDevices();
      });
    });
  }

  Future<void> enableBluetooth() async {
    _bluetoothState = await FlutterBluetoothSerial.instance.state;
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      await FlutterBluetoothSerial.instance.requestEnable();
      await getPairedDevices();
      return true;
    } else {
      await getPairedDevices();
    }
    return false;
  }

  Future<void> getPairedDevices() async {
    List<BluetoothDevice> devices = [];
    try {
      devices = await _bluetooth.getBondedDevices();
    } on PlatformException {
      print('Error');
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _devicesList = devices;
    });
  }

  Future show(
      {String message, Duration duration: const Duration(seconds: 3)}) async {
    await Future.delayed(Duration(milliseconds: 100));
    _scaffoldKey.currentState.showSnackBar(SnackBar(
      content: Text(message),
      duration: duration,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Bluetooth Controller'),
        centerTitle: true,
        actions: <Widget>[
          Tooltip(
              message: 'Refresh the list of bluetooth devices',
              child: IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: Colors.white,
                ),
                onPressed: () async {
                  await getPairedDevices().then((_) {
                    show(message: 'Device List Refreshed');
                  });
                },
              )),
          Tooltip(
            message: 'Open bluetooth settings',
            child: IconButton(
              icon: Icon(
                Icons.settings,
                color: Colors.white,
              ),
              onPressed: () {
                FlutterBluetoothSerial.instance.openSettings();
              },
            ),
          )
        ],
      ),
      body: Container(
        child: Column(
          children: <Widget>[
            Visibility(
              visible: _isButtonUnavailable &&
                  _bluetoothState == BluetoothState.STATE_ON,
              child: CircularProgressIndicator(
                backgroundColor: Colors.grey,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Bluetooth State: ',
                      style: TextStyle(color: Colors.black, fontSize: 18),
                    ),
                  ),
                  bluetoothSwitch()
                ],
              ),
            ),
            Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Paired Devices',
                    style: TextStyle(color: Colors.black, fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Device: ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      deviceDropDownList(),
                      SizedBox(
                        width: 20,
                      ),
                      connectionButton()
                    ],
                  ),
                ),
              ],
            ),
            Visibility(
              visible: _deviceState != 0,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Container(
                  alignment: Alignment.center,
                  child: LiteRollingSwitch(
                    value: false,
                    textOn: 'On',
                    textOff: 'Off',
                    colorOff: Colors.red,
                    colorOn: Colors.green,
                    iconOff: Icons.power_settings_new,
                    iconOn: Icons.lightbulb_outline,
                    textSize: 20,
                    onChanged: (bool state) {
                      if (_connected) {
                        if (state)
                          turnOn();
                        else
                          turnOff();
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget bluetoothSwitch() {
    return Switch(
      value: _bluetoothState.isEnabled,
      onChanged: (bool value) {
        future() async {
          if (value) {
            await FlutterBluetoothSerial.instance.requestEnable();
          } else {
            await FlutterBluetoothSerial.instance.requestDisable();
          }
          await getPairedDevices();
          _isButtonUnavailable = false;
          if (_connected) {
            _disconnect();
          }
        }

        future().then((_) {
          setState(() {});
        });
      },
    );
  }

  List<DropdownMenuItem<BluetoothDevice>> _getDeviceItems() {
    List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (_devicesList.isEmpty) {
      items.add(DropdownMenuItem(
        child: Text('None'),
      ));
    } else {
      _devicesList.forEach((device) {
        items.add(DropdownMenuItem(
          child: Text(device.name),
          value: device,
        ));
      });
    }
    return items;
  }

  void _connect() async {
    if (_device == null) {
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('No device selected'),
      ));
    } else {
      if (!isConnected) {
        await BluetoothConnection.toAddress(_device.address)
            .then((_connection) {
          _scaffoldKey.currentState.showSnackBar(SnackBar(
            content: Text('Connected'),
          ));
          connection = _connection;
          setState(() {
            _connected = true;
          });
          connection.input.listen(null).onDone(() {
            if (isDisconnecting) {
              print('Disconnected locally');
            } else {
              print('Disconnected remotely');
            }
            if (this.mounted) {
              setState(() {});
            }
          });
        }).catchError((error) {
          print('Cannot connect');
          print(error);
        });
        _deviceState = -1;
        _scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text('Connected'),
        ));
      }
    }
  }

  void _disconnect() async {
    await connection.close();
    _scaffoldKey.currentState.showSnackBar(SnackBar(
      content: Text('Disconnected'),
    ));
    if (!connection.isConnected) {
      setState(() {
        _connected = false;
      });
    }
  }

  Widget connectionButton() {
    return RaisedButton(
      onPressed:
          _isButtonUnavailable ? null : _connected ? _disconnect : _connect,
      child: Text(_connected ? 'Disconnect' : 'Connect'),
    );
  }

  void turnOn() async {
    connection.output.add(utf8.encode("1" + "\r\n"));
    await connection.output.allSent;
    setState(() {
      _deviceState = 1;
    });
  }

  void turnOff() async {
    connection.output.add(utf8.encode("0" + "\r\n"));
    await connection.output.allSent;
    setState(() {
      _deviceState = -1;
    });
  }

  Widget deviceDropDownList() {
    return DropdownButton(
      items: _getDeviceItems(),
      onChanged: (value) {
        setState(() {
          _device = value;
          _isButtonUnavailable = false;
        });
      },
      value: _devicesList.isNotEmpty ? _device : null,
    );
  }

  bool isDisconnecting;
  @override
  void dispose() {
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }
    super.dispose();
  }
}
