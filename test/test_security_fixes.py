"""针对安全加固改动的自检：默认密钥、设置接口脱敏、SSRF 防护、可编辑文件归属。"""
import tempfile
import unittest
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]

import os
import sys

if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

os.environ.setdefault("CHATGPT2API_AUTH_KEY", "test-key-for-local-security-tests")


class AuthKeyValidationTests(unittest.TestCase):
    def test_rejects_empty_and_known_defaults(self) -> None:
        from services import config as config_module

        for value in ("", None, "   ", "chatgpt2api", "ChatGPT2API", "drawbridge", "changeme", "admin"):
            with self.subTest(value=value):
                self.assertTrue(config_module._is_invalid_auth_key(value))

    def test_accepts_a_real_random_key(self) -> None:
        from services import config as config_module

        self.assertFalse(config_module._is_invalid_auth_key("9f2c1ab73e5d4c0f8b6a2e1d"))

    def test_store_refuses_to_start_on_default_key(self) -> None:
        from services import config as config_module

        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "config.json"
            path.write_text('{"auth-key": "chatgpt2api"}', encoding="utf-8")
            old_env = config_module.os.environ.pop("CHATGPT2API_AUTH_KEY", None)
            try:
                with self.assertRaises(ValueError):
                    config_module.ConfigStore(path)
            finally:
                if old_env is not None:
                    config_module.os.environ["CHATGPT2API_AUTH_KEY"] = old_env


class SettingsSecretMaskingTests(unittest.TestCase):
    """设置接口不能把明文密钥回传给浏览器；前端整体回写时也不能把密钥覆盖成掩码。"""

    def _make_store(self, tmp: str):
        from services import config as config_module

        path = Path(tmp) / "config.json"
        path.write_text('{"auth-key": "unit-test-key"}', encoding="utf-8")
        return config_module, config_module.ConfigStore(path)

    def test_get_masks_all_secret_fields(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            module, store = self._make_store(tmp)
            store.data["ai_review"] = {"enabled": True, "api_key": "sk-live-secret"}
            store.data["backup"] = {"secret_access_key": "r2-live-secret", "passphrase": "live-pass"}
            store.data["image_storage"] = {"enabled": False, "webdav_password": "webdav-live"}

            public = store.get()

            self.assertEqual(public["ai_review"]["api_key"], module.SECRET_MASK)
            self.assertEqual(public["backup"]["secret_access_key"], module.SECRET_MASK)
            self.assertEqual(public["backup"]["passphrase"], module.SECRET_MASK)
            self.assertEqual(public["image_storage"]["webdav_password"], module.SECRET_MASK)
            # 非密钥字段不受影响
            self.assertTrue(public["ai_review"]["enabled"])

    def test_update_restores_masked_secrets_instead_of_overwriting(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            module, store = self._make_store(tmp)
            store.data["ai_review"] = {"enabled": True, "api_key": "sk-live-secret"}
            store.data["backup"] = {"secret_access_key": "r2-live-secret", "passphrase": "live-pass"}
            store.data["image_storage"] = {"enabled": False, "webdav_password": "webdav-live"}

            store.update({
                "ai_review": {"enabled": False, "api_key": module.SECRET_MASK},
                "backup": {"secret_access_key": module.SECRET_MASK, "passphrase": module.SECRET_MASK},
                "image_storage": {"enabled": False, "webdav_password": module.SECRET_MASK},
            })

            self.assertEqual(store.data["ai_review"]["api_key"], "sk-live-secret")
            self.assertEqual(store.data["backup"]["secret_access_key"], "r2-live-secret")
            self.assertEqual(store.data["backup"]["passphrase"], "live-pass")
            self.assertEqual(store.data["image_storage"]["webdav_password"], "webdav-live")
            # 同一请求里真正被改动的字段要生效
            self.assertFalse(store.data["ai_review"]["enabled"])

    def test_update_accepts_a_genuinely_new_secret(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            _, store = self._make_store(tmp)
            store.data["ai_review"] = {"enabled": True, "api_key": "sk-old"}
            store.update({"ai_review": {"enabled": True, "api_key": "sk-brand-new"}})
            self.assertEqual(store.data["ai_review"]["api_key"], "sk-brand-new")

    def test_update_keeps_secret_when_field_is_absent(self) -> None:
        """只提交部分字段时不能把已保存的密钥静默清空。"""
        with tempfile.TemporaryDirectory() as tmp:
            _, store = self._make_store(tmp)
            store.data["backup"] = {"enabled": True, "secret_access_key": "r2-keep", "passphrase": "pw-keep"}
            store.update({"backup": {"enabled": True}})
            self.assertEqual(store.data["backup"]["secret_access_key"], "r2-keep")
            self.assertEqual(store.data["backup"]["passphrase"], "pw-keep")

    def test_update_clears_secret_when_explicitly_empty(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            _, store = self._make_store(tmp)
            store.data["backup"] = {"enabled": True, "secret_access_key": "r2-keep", "passphrase": "pw-keep"}
            store.update({"backup": {"enabled": True, "secret_access_key": "", "passphrase": ""}})
            self.assertEqual(store.data["backup"]["secret_access_key"], "")
            self.assertEqual(store.data["backup"]["passphrase"], "")


class AdminKeyComparisonTests(unittest.TestCase):
    """管理密钥比较必须常量时间，且不能被畸形输入打成 500。"""

    def test_non_ascii_bearer_does_not_crash(self) -> None:
        from api import support

        # compare_digest 直接吃含非 ASCII 的 str 会抛 TypeError → 500
        for token in ("café", "密钥", "sk-\u00e9\u00e9", "日本語"):
            with self.subTest(token=token):
                self.assertIsNone(support._legacy_admin_identity(token))

    def test_correct_admin_key_still_matches(self) -> None:
        from api import support

        identity = support._legacy_admin_identity("test-key-for-local-security-tests")
        self.assertIsNotNone(identity)
        self.assertEqual(identity["role"], "admin")


class ImageUrlSsrfGuardTests(unittest.TestCase):
    """图片 URL 抓取不能用来探测内网。"""

    def _assert_rejected(self, url: str) -> None:
        from fastapi import HTTPException

        from utils.helper import assert_public_http_url

        with self.assertRaises(HTTPException) as ctx:
            assert_public_http_url(url)
        self.assertIn(ctx.exception.status_code, (400,))

    def test_rejects_internal_targets(self) -> None:
        for url in (
            "http://127.0.0.1:8000/api/settings",
            "http://0.0.0.0/x",
            "http://10.1.2.3/x",
            "http://192.168.1.1/x",
            "http://172.16.5.4/x",
            "http://169.254.169.254/latest/meta-data/",
            "http://100.64.0.1/x",
            "http://[::1]/x",
            "http://[fd00::1]/x",
        ):
            with self.subTest(url=url):
                self._assert_rejected(url)

    def test_rejects_non_http_schemes(self) -> None:
        for url in ("file:///etc/passwd", "gopher://example.com/x", "ftp://example.com/x", "not-a-url"):
            with self.subTest(url=url):
                self._assert_rejected(url)

    def test_accepts_public_address(self) -> None:
        from utils.helper import assert_public_http_url

        assert_public_http_url("http://93.184.216.34/image.png")

    def test_all_fetchers_go_through_the_guard(self) -> None:
        """聊天/vision 链路也必须走同一个守卫，不能只有 images/edits 一处修了。"""
        import inspect

        from utils import helper

        source = inspect.getsource(helper._decode_message_image_url)
        self.assertIn("fetch_public_url_stream", source)
        self.assertNotIn("allow_redirects=True", source)


class EditableFileOwnershipTests(unittest.TestCase):
    """/files/{path} 只能拿到自己任务产出的文件。"""

    def test_owner_can_read_others_cannot(self) -> None:
        from services import editable_file_task_service as module

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            old_root = module.EDITABLE_FILE_ROOT
            old_tasks_path = module.EDITABLE_FILE_TASKS_PATH
            try:
                module.EDITABLE_FILE_ROOT = root
                module.EDITABLE_FILE_TASKS_PATH = root / "tasks.json"
                service = module.EditableFileTaskService(path=root / "tasks.json")
                service._tasks[module._task_key("alice", "t1")] = {
                    "id": "t1", "owner_id": "alice", "status": "success", "kind": "ppt",
                }
                target = root / "ppt" / "alice" / "t1" / "deck.pptx"
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(b"fake-pptx")
                rel = "ppt/alice/t1/deck.pptx"

                self.assertEqual(service.public_file_path(rel, {"id": "alice", "role": "user"}), target.resolve())
                with self.assertRaises(FileNotFoundError):
                    service.public_file_path(rel, {"id": "bob", "role": "user"})
                with self.assertRaises(FileNotFoundError):
                    service.public_file_path(rel, {"id": "carol", "role": "user"})
                # 管理员仍可访问
                self.assertEqual(service.public_file_path(rel, {"id": "root", "role": "admin"}), target.resolve())
            finally:
                module.EDITABLE_FILE_ROOT = old_root
                module.EDITABLE_FILE_TASKS_PATH = old_tasks_path

    def test_cannot_claim_someone_elses_task_id(self) -> None:
        """client_task_id 由调用方自选，用它建一个同 ID 的任务不能认领别人的产出目录。"""
        from services import editable_file_task_service as module

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            old_root = module.EDITABLE_FILE_ROOT
            old_tasks_path = module.EDITABLE_FILE_TASKS_PATH
            try:
                module.EDITABLE_FILE_ROOT = root
                module.EDITABLE_FILE_TASKS_PATH = root / "tasks.json"
                service = module.EditableFileTaskService(path=root / "tasks.json")
                # 受害者产出的文件在自己的目录下
                victim_rel = "ppt/victim/t9/deck.pptx"
                victim_file = root / victim_rel
                victim_file.parent.mkdir(parents=True, exist_ok=True)
                victim_file.write_bytes(b"victim-data")
                service._tasks[module._task_key("victim", "t9")] = {
                    "id": "t9", "owner_id": "victim", "status": "success", "kind": "ppt",
                }

                # 攻击者拿到同一个 task_id 也只能待在自己的目录里
                with self.assertRaises(FileNotFoundError):
                    service.public_file_path(victim_rel, {"id": "attacker", "role": "user"})
                attacker_rel = "ppt/attacker/t9/deck.pptx"
                attacker_file = root / attacker_rel
                attacker_file.parent.mkdir(parents=True, exist_ok=True)
                attacker_file.write_bytes(b"attacker-data")
                self.assertEqual(
                    service.public_file_path(attacker_rel, {"id": "attacker", "role": "user"}),
                    attacker_file.resolve(),
                )

                # 受害者仍能访问自己的文件（攻击者无法通过占位 ID 把对方锁死）
                self.assertEqual(
                    service.public_file_path(victim_rel, {"id": "victim", "role": "user"}),
                    victim_file.resolve(),
                )
            finally:
                module.EDITABLE_FILE_ROOT = old_root
                module.EDITABLE_FILE_TASKS_PATH = old_tasks_path


if __name__ == "__main__":
    unittest.main()
