import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'pages/config_page.dart';

void main() {
  // 确保 Flutter 引擎在启动前已完成初始化 (如果有些插件需要提前注册)
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ClawExampleApp());
}

class ClawExampleApp extends StatelessWidget {
  const ClawExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🌟 关键点：使用 GetMaterialApp 替代 MaterialApp
    // 这样底层沙盒的 UIPlugin 就可以在没有 BuildContext 的情况下直接弹窗了
    return GetMaterialApp(
      title: 'Claw OS Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, // 极客风暗色主题
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Overlay(
          initialEntries: [OverlayEntry(builder: (_) => child!)],
        );
      },
      // 启动后进入 API Key 配置页
      home: const ConfigPage(),
    );
  }
}