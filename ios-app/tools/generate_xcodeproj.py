#!/usr/bin/env python3
"""Genera Cash.xcodeproj (app + target di test) dai file sorgente.

Il file `project.pbxproj` è un elenco di oggetti collegati da identificatori a
24 cifre esadecimali. Scriverlo a mano è fragile; generarlo qui significa che
aggiungere un file al progetto è solo questione di rilanciare il comando:

    python3 tools/generate_xcodeproj.py
    python3 tools/validate_project.py

Gli identificatori derivano dall'hash del percorso, quindi rigenerando il
progetto non cambiano e il diff su git resta leggibile.
"""

import hashlib
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

APP = "Cash"
TESTS = "CashTests"

BUNDLE_ID = "com.giovannimaffei.Cash"
DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.0"
INFO_PLIST = f"{APP}/Resources/Info.plist"

FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".plist": "text.plist.xml",
    ".xcassets": "folder.assetcatalog",
    ".png": "image.png",
}


def uid(*parts):
    """Identificatore stabile a 24 cifre esadecimali, derivato dal percorso."""
    return hashlib.md5("::".join(parts).encode("utf-8")).hexdigest()[:24].upper()


def file_type(path):
    return FILE_TYPES.get(path.suffix, "text")


def collect(directory):
    """Trova sorgenti e risorse sotto una cartella, in ordine stabile."""
    sources, resources, referenced = [], [], []
    base = ROOT / directory

    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))

        for name in sorted(filenames):
            if name.startswith("."):
                continue
            relative = (Path(dirpath) / name).relative_to(ROOT)

            if name.endswith(".swift"):
                sources.append(relative)
            elif name == "Info.plist":
                # Referenziato dalle impostazioni di build, non copiato.
                referenced.append(relative)

        # I cataloghi di asset sono un'unica risorsa, non una cartella da
        # esplorare: Xcode li tratta come un file solo.
        for name in list(dirnames):
            if name.endswith(".xcassets"):
                resources.append((Path(dirpath) / name).relative_to(ROOT))
                dirnames.remove(name)

    return sources, resources, referenced


class Tree:
    """Ricostruisce l'albero dei gruppi di Xcode rispecchiando le cartelle."""

    def __init__(self):
        self.children = {}
        self.files = []

    def add(self, relative):
        node = self
        for part in relative.parts[:-1]:
            node = node.children.setdefault(part, Tree())
        node.files.append(relative)


def emit_groups(tree, path_parts, lines):
    """Emette ricorsivamente le sezioni PBXGroup, dal basso verso l'alto."""
    group_id = uid("group", "/".join(path_parts))
    children = []

    for name in sorted(tree.children):
        children.append((emit_groups(tree.children[name], path_parts + [name], lines), name))

    for relative in tree.files:
        children.append((uid("file", str(relative)), relative.name))

    entries = "\n".join(f"\t\t\t\t{cid} /* {name} */," for cid, name in children)
    name = path_parts[-1]

    lines.append(
        f"\t\t{group_id} /* {name} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n{entries}\n\t\t\t);\n"
        f"\t\t\tpath = {name};\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};"
    )
    return group_id


def settings(pairs):
    return "\n".join(f"\t\t\t\t{key} = {value};" for key, value in sorted(pairs))


def build_configuration(config_id, name, pairs):
    return (
        f"\t\t{config_id} /* {name} */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbuildSettings = {{\n{settings(pairs)}\n\t\t\t}};\n"
        f"\t\t\tname = {name};\n"
        f"\t\t}};"
    )


def project_settings(is_debug):
    pairs = [
        ("ALWAYS_SEARCH_USER_PATHS", "NO"),
        ("ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS", "YES"),
        ("CLANG_ANALYZER_NONNULL", "YES"),
        ("CLANG_ENABLE_MODULES", "YES"),
        ("CLANG_ENABLE_OBJC_ARC", "YES"),
        ("COPY_PHASE_STRIP", "NO"),
        ("DEBUG_INFORMATION_FORMAT", "dwarf" if is_debug else '"dwarf-with-dsym"'),
        ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
        ("ENABLE_USER_SCRIPT_SANDBOXING", "YES"),
        ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
        ("GCC_NO_COMMON_BLOCKS", "YES"),
        ("IPHONEOS_DEPLOYMENT_TARGET", DEPLOYMENT_TARGET),
        ("MTL_ENABLE_DEBUG_INFO", "INCLUDE_SOURCE" if is_debug else "NO"),
        ("MTL_FAST_MATH", "YES"),
        ("SDKROOT", "iphoneos"),
        ("SWIFT_VERSION", SWIFT_VERSION),
    ]
    if is_debug:
        pairs += [
            # Serve a `@testable import Cash`.
            ("ENABLE_TESTABILITY", "YES"),
            ("GCC_DYNAMIC_NO_PIC", "NO"),
            ("GCC_OPTIMIZATION_LEVEL", "0"),
            ("GCC_PREPROCESSOR_DEFINITIONS",
             '(\n\t\t\t\t\t"DEBUG=1",\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t)'),
            ("ONLY_ACTIVE_ARCH", "YES"),
            ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", '"DEBUG $(inherited)"'),
            ("SWIFT_OPTIMIZATION_LEVEL", '"-Onone"'),
        ]
    else:
        pairs += [
            ("ENABLE_NS_ASSERTIONS", "NO"),
            ("SWIFT_COMPILATION_MODE", "wholemodule"),
            ("VALIDATE_PRODUCT", "YES"),
        ]
    return pairs


def app_settings():
    return [
        ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
        ("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "AccentColor"),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("CURRENT_PROJECT_VERSION", "1"),
        ("ENABLE_PREVIEWS", "YES"),
        ("GENERATE_INFOPLIST_FILE", "NO"),
        ("INFOPLIST_FILE", INFO_PLIST),
        ("LD_RUNPATH_SEARCH_PATHS",
         '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t)'),
        ("MARKETING_VERSION", "1.0"),
        ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID),
        ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
        ("SWIFT_EMIT_LOC_STRINGS", "YES"),
        ("SWIFT_VERSION", SWIFT_VERSION),
        # 1 = solo iPhone. È la riga che rende l'app "iPhone only".
        ("TARGETED_DEVICE_FAMILY", "1"),
    ]


def test_settings():
    return [
        # I test girano dentro l'app: è ciò che dà accesso a `@testable`.
        ("BUNDLE_LOADER", '"$(TEST_HOST)"'),
        ("TEST_HOST",
         f'"$(BUILT_PRODUCTS_DIR)/{APP}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{APP}"'),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("CURRENT_PROJECT_VERSION", "1"),
        ("GENERATE_INFOPLIST_FILE", "YES"),
        ("MARKETING_VERSION", "1.0"),
        ("PRODUCT_BUNDLE_IDENTIFIER", f"{BUNDLE_ID}Tests"),
        ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
        ("SWIFT_EMIT_LOC_STRINGS", "NO"),
        ("SWIFT_VERSION", SWIFT_VERSION),
        ("TARGETED_DEVICE_FAMILY", "1"),
        ("IPHONEOS_DEPLOYMENT_TARGET", DEPLOYMENT_TARGET),
    ]


def generate():
    app_sources, app_assets, app_referenced = collect(APP)
    test_sources, _, _ = collect(TESTS)

    ids = {
        "project": uid("project"),
        "main_group": uid("maingroup"),
        "products_group": uid("group", "Products"),
        "app_target": uid("target", APP),
        "test_target": uid("target", TESTS),
        "app_product": uid("product", APP),
        "test_product": uid("product", TESTS),
        "app_sources": uid("phase", "app", "sources"),
        "app_frameworks": uid("phase", "app", "frameworks"),
        "app_resources": uid("phase", "app", "resources"),
        "test_sources": uid("phase", "test", "sources"),
        "test_frameworks": uid("phase", "test", "frameworks"),
        "test_resources": uid("phase", "test", "resources"),
        "proxy": uid("proxy", TESTS),
        "dependency": uid("dependency", TESTS),
        "project_configs": uid("configlist", "project"),
        "app_configs": uid("configlist", "app"),
        "test_configs": uid("configlist", "test"),
    }

    out = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {", "\t};",
           "\tobjectVersion = 56;", "\tobjects = {", ""]

    # --- PBXBuildFile ---------------------------------------------------
    out.append("/* Begin PBXBuildFile section */")
    for path in app_sources:
        out.append(f"\t\t{uid('build', str(path))} /* {path.name} in Sources */ = "
                   f"{{isa = PBXBuildFile; fileRef = {uid('file', str(path))} /* {path.name} */; }};")
    for path in test_sources:
        out.append(f"\t\t{uid('build', str(path))} /* {path.name} in Sources */ = "
                   f"{{isa = PBXBuildFile; fileRef = {uid('file', str(path))} /* {path.name} */; }};")
    for path in app_assets:
        out.append(f"\t\t{uid('build', str(path))} /* {path.name} in Resources */ = "
                   f"{{isa = PBXBuildFile; fileRef = {uid('file', str(path))} /* {path.name} */; }};")
    out.append("/* End PBXBuildFile section */\n")

    # --- PBXContainerItemProxy / PBXTargetDependency --------------------
    out.append("/* Begin PBXContainerItemProxy section */")
    out.append(
        f"\t\t{ids['proxy']} /* PBXContainerItemProxy */ = {{\n"
        f"\t\t\tisa = PBXContainerItemProxy;\n"
        f"\t\t\tcontainerPortal = {ids['project']} /* Project object */;\n"
        f"\t\t\tproxyType = 1;\n"
        f"\t\t\tremoteGlobalIDString = {ids['app_target']};\n"
        f"\t\t\tremoteInfo = {APP};\n"
        f"\t\t}};"
    )
    out.append("/* End PBXContainerItemProxy section */\n")

    # --- PBXFileReference -----------------------------------------------
    out.append("/* Begin PBXFileReference section */")
    out.append(f"\t\t{ids['app_product']} /* {APP}.app */ = {{isa = PBXFileReference; "
               f"explicitFileType = wrapper.application; includeInIndex = 0; "
               f"path = {APP}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    out.append(f"\t\t{ids['test_product']} /* {TESTS}.xctest */ = {{isa = PBXFileReference; "
               f"explicitFileType = wrapper.cfbundle; includeInIndex = 0; "
               f"path = {TESTS}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")

    every_file = app_sources + app_assets + app_referenced + test_sources
    for path in every_file:
        out.append(f"\t\t{uid('file', str(path))} /* {path.name} */ = {{isa = PBXFileReference; "
                   f"lastKnownFileType = {file_type(path)}; path = {path.name}; "
                   f"sourceTree = \"<group>\"; }};")
    out.append("/* End PBXFileReference section */\n")

    # --- Frameworks ------------------------------------------------------
    out.append("/* Begin PBXFrameworksBuildPhase section */")
    for key in ("app_frameworks", "test_frameworks"):
        out.append(f"\t\t{ids[key]} /* Frameworks */ = {{\n"
                   f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
                   f"\t\t\tbuildActionMask = 2147483647;\n"
                   f"\t\t\tfiles = (\n\t\t\t);\n"
                   f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")
    out.append("/* End PBXFrameworksBuildPhase section */\n")

    # --- Gruppi ----------------------------------------------------------
    app_tree, test_tree = Tree(), Tree()
    for path in app_sources + app_assets + app_referenced:
        app_tree.add(path)
    for path in test_sources:
        test_tree.add(path)

    group_lines = []
    app_group = emit_groups(app_tree.children[APP], [APP], group_lines)
    test_group = emit_groups(test_tree.children[TESTS], [TESTS], group_lines)

    out.append("/* Begin PBXGroup section */")
    out.append(f"\t\t{ids['main_group']} = {{\n"
               f"\t\t\tisa = PBXGroup;\n"
               f"\t\t\tchildren = (\n"
               f"\t\t\t\t{app_group} /* {APP} */,\n"
               f"\t\t\t\t{test_group} /* {TESTS} */,\n"
               f"\t\t\t\t{ids['products_group']} /* Products */,\n"
               f"\t\t\t);\n"
               f"\t\t\tsourceTree = \"<group>\";\n\t\t}};")
    out.append(f"\t\t{ids['products_group']} /* Products */ = {{\n"
               f"\t\t\tisa = PBXGroup;\n"
               f"\t\t\tchildren = (\n"
               f"\t\t\t\t{ids['app_product']} /* {APP}.app */,\n"
               f"\t\t\t\t{ids['test_product']} /* {TESTS}.xctest */,\n"
               f"\t\t\t);\n"
               f"\t\t\tname = Products;\n"
               f"\t\t\tsourceTree = \"<group>\";\n\t\t}};")
    out.extend(group_lines)
    out.append("/* End PBXGroup section */\n")

    # --- Target ----------------------------------------------------------
    out.append("/* Begin PBXNativeTarget section */")
    out.append(f"\t\t{ids['app_target']} /* {APP} */ = {{\n"
               f"\t\t\tisa = PBXNativeTarget;\n"
               f"\t\t\tbuildConfigurationList = {ids['app_configs']};\n"
               f"\t\t\tbuildPhases = (\n"
               f"\t\t\t\t{ids['app_sources']} /* Sources */,\n"
               f"\t\t\t\t{ids['app_frameworks']} /* Frameworks */,\n"
               f"\t\t\t\t{ids['app_resources']} /* Resources */,\n"
               f"\t\t\t);\n"
               f"\t\t\tbuildRules = (\n\t\t\t);\n"
               f"\t\t\tdependencies = (\n\t\t\t);\n"
               f"\t\t\tname = {APP};\n"
               f"\t\t\tproductName = {APP};\n"
               f"\t\t\tproductReference = {ids['app_product']} /* {APP}.app */;\n"
               f"\t\t\tproductType = \"com.apple.product-type.application\";\n\t\t}};")
    out.append(f"\t\t{ids['test_target']} /* {TESTS} */ = {{\n"
               f"\t\t\tisa = PBXNativeTarget;\n"
               f"\t\t\tbuildConfigurationList = {ids['test_configs']};\n"
               f"\t\t\tbuildPhases = (\n"
               f"\t\t\t\t{ids['test_sources']} /* Sources */,\n"
               f"\t\t\t\t{ids['test_frameworks']} /* Frameworks */,\n"
               f"\t\t\t\t{ids['test_resources']} /* Resources */,\n"
               f"\t\t\t);\n"
               f"\t\t\tbuildRules = (\n\t\t\t);\n"
               f"\t\t\tdependencies = (\n\t\t\t\t{ids['dependency']} /* PBXTargetDependency */,\n\t\t\t);\n"
               f"\t\t\tname = {TESTS};\n"
               f"\t\t\tproductName = {TESTS};\n"
               f"\t\t\tproductReference = {ids['test_product']} /* {TESTS}.xctest */;\n"
               f"\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";\n\t\t}};")
    out.append("/* End PBXNativeTarget section */\n")

    # --- Progetto ---------------------------------------------------------
    out.append("/* Begin PBXProject section */")
    out.append(f"\t\t{ids['project']} /* Project object */ = {{\n"
               f"\t\t\tisa = PBXProject;\n"
               f"\t\t\tattributes = {{\n"
               f"\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
               f"\t\t\t\tLastSwiftUpdateCheck = 1520;\n"
               f"\t\t\t\tLastUpgradeCheck = 1520;\n"
               f"\t\t\t\tTargetAttributes = {{\n"
               f"\t\t\t\t\t{ids['app_target']} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.2;\n\t\t\t\t\t}};\n"
               f"\t\t\t\t\t{ids['test_target']} = {{\n"
               f"\t\t\t\t\t\tCreatedOnToolsVersion = 15.2;\n"
               f"\t\t\t\t\t\tTestTargetID = {ids['app_target']};\n\t\t\t\t\t}};\n"
               f"\t\t\t\t}};\n"
               f"\t\t\t}};\n"
               f"\t\t\tbuildConfigurationList = {ids['project_configs']};\n"
               f"\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n"
               f"\t\t\tdevelopmentRegion = it;\n"
               f"\t\t\thasScannedForEncodings = 0;\n"
               f"\t\t\tknownRegions = (\n\t\t\t\tit,\n\t\t\t\tBase,\n\t\t\t);\n"
               f"\t\t\tmainGroup = {ids['main_group']};\n"
               f"\t\t\tproductRefGroup = {ids['products_group']} /* Products */;\n"
               f"\t\t\tprojectDirPath = \"\";\n"
               f"\t\t\tprojectRoot = \"\";\n"
               f"\t\t\ttargets = (\n"
               f"\t\t\t\t{ids['app_target']} /* {APP} */,\n"
               f"\t\t\t\t{ids['test_target']} /* {TESTS} */,\n"
               f"\t\t\t);\n\t\t}};")
    out.append("/* End PBXProject section */\n")

    # --- Resources --------------------------------------------------------
    asset_entries = "\n".join(
        f"\t\t\t\t{uid('build', str(p))} /* {p.name} in Resources */," for p in app_assets
    )
    out.append("/* Begin PBXResourcesBuildPhase section */")
    out.append(f"\t\t{ids['app_resources']} /* Resources */ = {{\n"
               f"\t\t\tisa = PBXResourcesBuildPhase;\n"
               f"\t\t\tbuildActionMask = 2147483647;\n"
               f"\t\t\tfiles = (\n{asset_entries}\n\t\t\t);\n"
               f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")
    out.append(f"\t\t{ids['test_resources']} /* Resources */ = {{\n"
               f"\t\t\tisa = PBXResourcesBuildPhase;\n"
               f"\t\t\tbuildActionMask = 2147483647;\n"
               f"\t\t\tfiles = (\n\t\t\t);\n"
               f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")
    out.append("/* End PBXResourcesBuildPhase section */\n")

    # --- Sources ----------------------------------------------------------
    out.append("/* Begin PBXSourcesBuildPhase section */")
    for key, paths in (("app_sources", app_sources), ("test_sources", test_sources)):
        entries = "\n".join(
            f"\t\t\t\t{uid('build', str(p))} /* {p.name} in Sources */," for p in paths
        )
        out.append(f"\t\t{ids[key]} /* Sources */ = {{\n"
                   f"\t\t\tisa = PBXSourcesBuildPhase;\n"
                   f"\t\t\tbuildActionMask = 2147483647;\n"
                   f"\t\t\tfiles = (\n{entries}\n\t\t\t);\n"
                   f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};")
    out.append("/* End PBXSourcesBuildPhase section */\n")

    # --- Dipendenza -------------------------------------------------------
    out.append("/* Begin PBXTargetDependency section */")
    out.append(f"\t\t{ids['dependency']} /* PBXTargetDependency */ = {{\n"
               f"\t\t\tisa = PBXTargetDependency;\n"
               f"\t\t\ttarget = {ids['app_target']} /* {APP} */;\n"
               f"\t\t\ttargetProxy = {ids['proxy']} /* PBXContainerItemProxy */;\n\t\t}};")
    out.append("/* End PBXTargetDependency section */\n")

    # --- Configurazioni ---------------------------------------------------
    out.append("/* Begin XCBuildConfiguration section */")
    for name in ("Debug", "Release"):
        is_debug = name == "Debug"
        out.append(build_configuration(uid("config", "project", name), name, project_settings(is_debug)))
        out.append(build_configuration(uid("config", "app", name), name, app_settings()))
        out.append(build_configuration(uid("config", "test", name), name, test_settings()))
    out.append("/* End XCBuildConfiguration section */\n")

    out.append("/* Begin XCConfigurationList section */")
    for list_key, scope in (("project_configs", "project"), ("app_configs", "app"), ("test_configs", "test")):
        out.append(f"\t\t{ids[list_key]} = {{\n"
                   f"\t\t\tisa = XCConfigurationList;\n"
                   f"\t\t\tbuildConfigurations = (\n"
                   f"\t\t\t\t{uid('config', scope, 'Debug')} /* Debug */,\n"
                   f"\t\t\t\t{uid('config', scope, 'Release')} /* Release */,\n"
                   f"\t\t\t);\n"
                   f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
                   f"\t\t\tdefaultConfigurationName = Release;\n\t\t}};")
    out.append("/* End XCConfigurationList section */\n")

    out.append("\t};")
    out.append(f"\trootObject = {ids['project']} /* Project object */;")
    out.append("}")

    project_dir = ROOT / f"{APP}.xcodeproj"
    project_dir.mkdir(parents=True, exist_ok=True)
    (project_dir / "project.pbxproj").write_text("\n".join(out) + "\n", encoding="utf-8")

    write_scheme(project_dir, ids)
    return len(app_sources), len(test_sources), len(app_assets)


def write_scheme(project_dir, ids):
    """Lo schema condiviso, con i test collegati: senza, Xcode ne creerebbe
    uno al volo che non finisce su git e ⌘U non troverebbe nulla da eseguire."""
    scheme_dir = project_dir / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)

    container = f"container:{APP}.xcodeproj"

    def buildable(target_id, name, product):
        return (f'            <BuildableReference\n'
                f'               BuildableIdentifier = "primary"\n'
                f'               BlueprintIdentifier = "{target_id}"\n'
                f'               BuildableName = "{product}"\n'
                f'               BlueprintName = "{name}"\n'
                f'               ReferencedContainer = "{container}">\n'
                f'            </BuildableReference>')

    app_ref = buildable(ids["app_target"], APP, f"{APP}.app")
    test_ref = buildable(ids["test_target"], TESTS, f"{TESTS}.xctest")

    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1520" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
{app_ref}
         </BuildActionEntry>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "NO" buildForProfiling = "NO" buildForArchiving = "NO" buildForAnalyzing = "NO">
{test_ref}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
{test_ref}
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
{app_ref}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
{app_ref}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    (scheme_dir / f"{APP}.xcscheme").write_text(scheme, encoding="utf-8")


if __name__ == "__main__":
    app_count, test_count, asset_count = generate()
    print(f"{APP}.xcodeproj generato: {app_count} sorgenti app, "
          f"{test_count} sorgenti test, {asset_count} risorse.")
