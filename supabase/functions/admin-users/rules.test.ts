// Pruebas de las reglas de la Edge Function admin-users.
// Ejecutar desde la raíz del proyecto:  node --test supabase/functions/admin-users/
import assert from "node:assert/strict";
import { describe, test } from "node:test";

import {
  HttpError,
  parseTargetUserId,
  type StaffRow,
  validateCreateStaff,
  validateDeleteUser,
} from "./rules.ts";

const superAdmin: StaffRow = { user_id: "sa", is_super_admin: true, permissions: [], is_active: true };
const hrAdmin: StaffRow = {
  user_id: "hr",
  is_super_admin: false,
  permissions: ["employeeManagement", "userManagement", "dashboard"],
  is_active: true,
};
const supportAdmin: StaffRow = {
  user_id: "sup",
  is_super_admin: false,
  permissions: ["userManagement"],
  is_active: true,
};
const TARGET = "11111111-1111-1111-1111-111111111111";

function rejects(fn: () => unknown, status: number, messagePart: string) {
  assert.throws(fn, (e: unknown) => {
    assert.ok(e instanceof HttpError, "debe lanzar HttpError");
    assert.equal(e.status, status);
    assert.match(e.message, new RegExp(messagePart));
    return true;
  });
}

describe("create_staff", () => {
  test("un usuario que no es staff no puede crear empleados", () => {
    rejects(() => validateCreateStaff(null, { email: "a@b.com", permissions: ["dashboard"] }), 403, "employeeManagement");
  });

  test("un staff inactivo pierde sus permisos", () => {
    rejects(
      () => validateCreateStaff({ ...hrAdmin, is_active: false }, { email: "a@b.com", permissions: ["dashboard"] }),
      403,
      "employeeManagement",
    );
  });

  test("normaliza el correo y quita permisos repetidos", () => {
    const input = validateCreateStaff(hrAdmin, {
      email: "  Nuevo@AgroTrade.com ",
      name: "Ana",
      permissions: ["dashboard", "dashboard", "userManagement"],
    });
    assert.equal(input.email, "nuevo@agrotrade.com");
    assert.deepEqual(input.permissions, ["dashboard", "userManagement"]);
    assert.equal(input.isSuperAdmin, false);
  });

  test("rechaza correos y permisos inválidos", () => {
    rejects(() => validateCreateStaff(hrAdmin, { email: "no-es-correo", permissions: ["dashboard"] }), 400, "correo");
    rejects(() => validateCreateStaff(hrAdmin, { email: "a@b.com", permissions: ["hackear"] }), 400, "hackear");
    rejects(() => validateCreateStaff(hrAdmin, { email: "a@b.com", permissions: [] }), 400, "al menos un permiso");
  });

  test("un admin normal no crea super admins ni da permisos que no tiene", () => {
    rejects(() => validateCreateStaff(hrAdmin, { email: "a@b.com", is_super_admin: true }), 403, "super admin");
    rejects(
      () => validateCreateStaff(hrAdmin, { email: "a@b.com", permissions: ["security"] }),
      403,
      "security",
    );
  });

  test("el super admin puede crear otro super admin sin permisos explícitos", () => {
    const input = validateCreateStaff(superAdmin, { email: "jefe@b.com", is_super_admin: true });
    assert.equal(input.isSuperAdmin, true);
  });
});

describe("delete_user", () => {
  const base = { callerId: "hr", caller: hrAdmin, targetId: TARGET, targetStaff: null, confirmedDeals: 0 };

  test("valida el formato del id (evita inyección en filtros)", () => {
    assert.equal(parseTargetUserId({ user_id: TARGET.toUpperCase() }), TARGET);
    rejects(() => parseTargetUserId({ user_id: "x,seller_id.eq.y" }), 400, "user_id");
  });

  test("requiere userManagement", () => {
    rejects(() => validateDeleteUser({ ...base, caller: null }), 403, "userManagement");
  });

  test("nadie borra su propia cuenta", () => {
    rejects(() => validateDeleteUser({ ...base, callerId: TARGET }), 400, "propia cuenta");
  });

  test("borrar staff requiere employeeManagement; super admin solo lo borra otro super admin", () => {
    const staffTarget: StaffRow = { user_id: TARGET, is_super_admin: false, permissions: ["dashboard"], is_active: true };
    rejects(() => validateDeleteUser({ ...base, caller: supportAdmin, targetStaff: staffTarget }), 403, "employeeManagement");
    rejects(
      () => validateDeleteUser({ ...base, targetStaff: { ...staffTarget, is_super_admin: true } }),
      403,
      "super admin",
    );
    assert.doesNotThrow(() => validateDeleteUser({ ...base, targetStaff: staffTarget }));
  });

  test("no borra cuentas con tratos confirmados", () => {
    rejects(() => validateDeleteUser({ ...base, confirmedDeals: 2 }), 409, "Bloquéalo");
  });

  test("permite borrar un usuario normal sin tratos confirmados", () => {
    assert.doesNotThrow(() => validateDeleteUser(base));
  });
});
