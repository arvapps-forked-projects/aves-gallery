import 'package:aves/model/apps.dart';
import 'package:aves/services/app_service.dart';
import 'package:flutter/foundation.dart';
import 'package:test/fake.dart';

class FakeAppService extends Fake implements AppService {
  @override
  Future<Set<Package>> getPackages() => SynchronousFuture({});
}
