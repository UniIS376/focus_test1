import 'package:workmanager/workmanager.dart';

const String simpleTaskKey = "simpleTask";

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // 여기에서 백그라운드 작업을 수행하세요
    print("Background task executed: $task");
    return Future.value(true);
  });
}

Future<void> initializeWorkmanager() async {
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
}
