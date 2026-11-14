"""Project naming and installed-app identity contracts."""
import json
from pathlib import Path
import subprocess
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]


class ProductIdentityTests(unittest.TestCase):
    def test_project_products_and_installed_identity(self):
        result = subprocess.check_output([
            "plutil", "-convert", "json", "-o", "-",
            str(ROOT / "businessToGoTime.xcodeproj/project.pbxproj"),
        ])
        objects = json.loads(result)["objects"]
        app = objects["84C5A2912BC40EEC00C25A0C"]
        self.assertEqual(app["name"], "businessToGoTime")
        self.assertEqual(objects[app["productReference"]]["path"], "businessToGoTime.app")
        configs = objects[app["buildConfigurationList"]]["buildConfigurations"]

        for config in configs:
            settings = objects[config]["buildSettings"]
            self.assertEqual(settings["INFOPLIST_KEY_CFBundleDisplayName"], "businessToGo Time")
            self.assertEqual(settings["PRODUCT_BUNDLE_IDENTIFIER"], "de.selch.businessToGo")
            self.assertTrue((ROOT / settings["INFOPLIST_FILE"]).is_file())
            self.assertTrue((ROOT / settings["CODE_SIGN_ENTITLEMENTS"]).is_file())

    def test_shared_scheme_and_test_plan_use_renamed_project(self):
        scheme = ET.parse(ROOT / "businessToGoTime.xcodeproj/xcshareddata/xcschemes/businessToGoTime.xcscheme")
        for reference in scheme.findall(".//BuildableReference"):
            self.assertEqual(reference.attrib["ReferencedContainer"], "container:businessToGoTime.xcodeproj")
        plan_reference = scheme.find(".//TestPlanReference").attrib["reference"]
        plan = json.loads((ROOT / plan_reference.removeprefix("container:")).read_text())
        target = plan["testTargets"][0]["target"]
        self.assertEqual(target["containerPath"], "container:businessToGoTime.xcodeproj")
        self.assertEqual(target["name"], "businessToGoTimeTests")
        self.assertTrue((ROOT / target["name"]).is_dir())

    def test_account_database_names_remain_unchanged(self):
        source = (ROOT / "Modules/Login/Sources/App/LoginReducer.swift").read_text()
        self.assertEqual(source.count('"businessToGo_\\(account.identifier).sqlite"'), 2)


if __name__ == "__main__":
    unittest.main()
