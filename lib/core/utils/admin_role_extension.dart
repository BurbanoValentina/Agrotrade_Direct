import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/admin_employee.dart';
import '../../providers/admin_provider.dart';

extension AdminRoleContext on BuildContext {
  AdminEmployee? get currentEmployee =>
      watch<AdminProvider>().currentEmployee;

  bool get isSuperAdmin => currentEmployee?.isSuperAdmin ?? false;

  bool get isManager =>
      !isSuperAdmin && (currentEmployee?.isManager ?? false);

  bool get canModifySystem => isSuperAdmin;
}
