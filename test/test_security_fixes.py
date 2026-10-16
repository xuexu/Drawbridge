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


class ImageUrlSsrfGuardTests(unittest.TestCase):
    """图片 URL 抓取不能用来探测内网。"""

    def _assert_rejected(self, url: str) -> None:
        from fastapi import HTTPException

        from api import image_inputs

        with self.assertRaises(HTTPException) as ctx:
            image_inputs._assert_public_url(url)
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
        from api import image_inputs

        image_inputs._assert_public_url("http://93.184.216.34/image.png")


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
                target = root / "ppt" / "t1" / "deck.pptx"
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(b"fake-pptx")
                rel = "ppt/t1/deck.pptx"

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


if __name__ == "__main__":
    unittest.main()
