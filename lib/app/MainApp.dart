import 'dart:io';

import 'package:cloudreve/utils/HttpUtil.dart';
import 'package:cloudreve/view/Home.dart';
import 'package:cloudreve/view/Setting.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloudreve/entity/File.dart';

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  String _path = "/";
  double _processNum = -1;

  Future<Response>? _fileResp;
  int _lastRequest = -1;

  Mode _mode = Mode.grid;

  void _refreshFileList(bool immediately) {
    if (immediately) {
      _lastRequest = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _fileResp = HttpUtil.dio.get('/api/v3/directory$_path');
      });
      HttpUtil.dio.get("/api/v3/user/storage");
    } else {
      int now = DateTime.now().millisecondsSinceEpoch;
      if (_lastRequest == -1 || (now - _lastRequest) / 1000 / 60 > 1) {
        _lastRequest = DateTime.now().millisecondsSinceEpoch;
        setState(() {
          _fileResp = HttpUtil.dio.get('/api/v3/directory$_path');
        });
        HttpUtil.dio.get("/api/v3/user/storage");
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    _refreshFileList(false);

    Icon icon = Icon(Icons.list);
    if (_mode == Mode.list) {
      icon = Icon(Icons.list);
    } else if (_mode == Mode.grid) {
      icon = Icon(Icons.grid_4x4_outlined);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloudreve'),
        actions: [
          IconButton(
              onPressed: () {
                if (_mode == Mode.list) {
                  setState(() {
                    _mode = Mode.grid;
                  });
                } else {
                  setState(() {
                    _mode = Mode.list;
                  });
                }
              },
              icon: icon),
          IconButton(
            onPressed: () {
              _refreshFileList(true);
            },
            icon: Icon(Icons.refresh),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          var result =
              await FilePicker.platform.pickFiles(withReadStream: true);
          if (result != null) {
            var file = result.files.first;
            var option = Options(
                method: "POST",
                contentType: "application/octet-stream",
                headers: {
                  "x-filename": Uri.encodeComponent(file.name),
                  "x-path": Uri.encodeComponent(_path),
                  HttpHeaders.contentLengthHeader: file.size
                },
                sendTimeout: 100000);
            Response res = await HttpUtil.dio.post("/api/v3/file/upload",
                options: option,
                data: file.readStream, onSendProgress: (process, total) {
              setState(() {
                _processNum = process / total;
              });
            });

            if (res.statusCode == 200) {
              String text;
              if (_path == '/') {
                text = "上传成功:$_path${file.name}";
              } else {
                text = "上传成功:$_path/${file.name}";
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(text),
                ),
              );
              setState(() {
                _processNum = -1;
              });
              _refreshFileList(true);
            }
          }
        },
        tooltip: '上传文件',
        child: const Icon(Icons.add),
      ),
      // drawer: Drawer(
      //   child: ListView(
      //     padding: EdgeInsets.zero,
      //     children: const <Widget>[
      //       DrawerHeader(
      //         decoration: BoxDecoration(
      //           color: Colors.blue,
      //         ),
      //         child: Text(
      //           'Drawer Header',
      //           style: TextStyle(
      //             color: Colors.white,
      //             fontSize: 24,
      //           ),
      //         ),
      //       ),
      //       ListTile(
      //         leading: Icon(Icons.message),
      //         title: Text('Messages'),
      //       ),
      //       ListTile(
      //         leading: Icon(Icons.account_circle),
      //         title: Text('Profile'),
      //       ),
      //       ListTile(
      //         leading: Icon(Icons.settings),
      //         title: Text('Settings'),
      //       ),
      //     ],
      //   ),
      // ),
      body: Center(
        child: IndexedStack(
          children: <Widget>[
            Home(
              mode: _mode,
              refresh: _refreshFileList,
              progressNum: _processNum,
              path: _path,
              fileResp: _fileResp!,
              changePath: (String newPath) {
                setState(() {
                  _path = newPath;
                });
              },
              changeProgressNum: (double newNum) {
                setState(() {
                  _processNum = newNum;
                });
              },
            ),
            Setting()
          ],
          index: _selectedIndex,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}
