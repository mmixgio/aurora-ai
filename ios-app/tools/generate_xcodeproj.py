#!/usr/bin/env python3
"""Genera Cash.xcodeproj a partire dai file sorgente.

Il file `project.pbxproj` di Xcode è un elenco di oggetti collegati fra loro
da identificatori a 24 cifre esadecimali. Scriverlo a mano è noioso e fragile;
generarlo con questo script significa che aggiungere un file allo schema è
solo questione di rilanciare il comando:

    python3 tools/generate_xcodeproj.py

Gli identificatori derivano dall'hash del percorso, quindi rigenerando il
progetto restano gli stessi e il diff su git resta leggibile.
"""

import hashlib
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_NAME = "Cash"
SOURCE_DIR = ROOT / APP_NAME
PROJECT_DIR = ROOT / f"{APP_NAME}.xcodeproj"

BUNDLE_ID = "com.giovannimaffei.Cash"
DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.0"


def uid(*parts):
    """Un identificatore stabile a 24 cifre esadecimali, derivato dal percorso."""
    digest = hashlib.md5("::".join(parts).encode("utf-8")).hexdigest()
    return digest[:24].upper()


def collect():
    """Trova i sorgenti e le risorse, in ordine stabile."""
    sources, resources = [], []

    for dirpath, dirnames, filenames in os.walk(SOURCE_DIR):
        # I cataloghi di asset sono un'unica risorsa, non una cartella da
        # esplorare: Xcode li tratta come un file solo.
        if dirpath.endswith(".xcassets"):
            dirnames[:] = []
            continue

        dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))

        for name in sorted(filenames):
            if name.startswith("."):
                continue
            path = Path(dirpath) / name
            relative = path.relative_to(ROOT)

            if name.endswith(".swift"):
                sources.append(relative)
            elif name == "Info.plist":
                resources.append((relative, False))    # referenziato, non copiato

        for name in list(dirnames):
            if name.endswith(".xcassets"):
                relative = (Path(dirpath) / name).relative_to(ROOT)
                resources.append((relative, True))
                dirnames.remove(name)

    return sources, resources


FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".plist": "text.plist.xml",
    ".xcassets": "folder.assetcatalog",
    ".png": "image.png",
}


def file_type(path):
    return FILE_TYPES.get(path.suffix, "text")


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


def build_groups(tree, path_parts, lines):
    """Emette ricorsivamente le sezioni PBXGroup, dal basso verso l'alto."""
    group_id = uid("group", "/".join(path_parts) or "<root>")
    children = []

    for name in sorted(tree.children):
        child_id = build_groups(tree.children[name], path_parts + [name], lines)
        children.append((child_id, name))

    for relative in tree.files:
        children.append((uid("file", str(relative)), relative.name))

    entries = "\n".join(
        f"\t\t\t\t{child_id} /* {name} */," for child_id, name in children
    )
    name = path_parts[-1] if path_parts else APP_NAME

    lines.append(
        f"\t\t{group_id} /* {name} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n{entries}\n\t\t\t);\n"
        + (f"\t\t\tpath = {name};\n" if path_parts else f"\t\t\tname = {name};\n")
        + f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};"
    )
    return group_id


def generate():
    sources, resources = collect()
    copied_resources = [path for path, copied in resources if copied]

    project_id = uid("project")
    target_id = uid("target", APP_NAME)
    product_id = uid("product", APP_NAME)
    products_group_id = uid("group", "Products")
    main_group_id = uid("maingroup")

    sources_phase_id = uid("phase", "sources")
    frameworks_phase_id = uid("phase", "frameworks")
    resources_phase_id = uid("phase", "resources")

    project_config_list_id = uid("configlist", "project")
    target_config_list_id = uid("configlist", "target")

    out = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {",
           "\t};", "\tobjectVersion = 56;", "\tobjects = {", ""]

    # --- PBXBuildFile -------------------------------------------------------
    out.append("/* Begin PBXBuildFile section */")
    for relative in sources:
        out.append(
            f"\t\t{uid('build', str(relative))} /* {relative.name} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {uid('file', str(relative))} /* {relative.name} */; }};"
        )
    for relative in copied_resources:
        out.append(
            f"\t\t{uid('build', str(relative))} /* {relative.name} in Resources */ = "
            f"{{isa = PBXBuildFile; fileRef = {uid('file', str(relative))} /* {relative.name} */; }};"
        )
    out.append("/* End PBXBuildFile section */")
    out.append("")

    # --- PBXFileReference ---------------------------------------------------
    out.append("/* Begin PBXFileReference section */")
    out.append(
        f"\t\t{product_id} /* {APP_NAME}.app */ = {{isa = PBXFileReference; "
        f"explicitFileType = wrapper.application; includeInIndex = 0; "
        f"path = {APP_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    every_file = list(sources) + [path for path, _ in resources]
    for relative in every_file:
        out.append(
            f"\t\t{uid('file', str(relative))} /* {relative.name} */ = {{isa = PBXFileReference; "
            f"lastKnownFileType = {file_type(relative)}; path = {relative.name}; "
            f"sourceTree = \"<group>\"; }};"
        )
    out.append("/* End PBXFileReference section */")
    out.append("")

    # --- Fasi di build ------------------------------------------------------
    out.append("/* Begin PBXFrameworksBuildPhase section */")
    out.append(
        f"\t\t{frameworks_phase_id} /* Frameworks */ = {{\n"
        f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};"
    )
    out.append("/* End PBXFrameworksBuildPhase section */")
    out.append("")

    # --- Gruppi -------------------------------------------------------------
    tree = Tree()
    for relative in every_file:
        tree.add(relative)

    group_lines = []
    app_group_id = build_groups(tree.children[APP_NAME], [APP_NAME], group_lines)

    out.append("/* Begin PBXGroup section */")
    out.append(
        f"\t\t{main_group_id} = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        f"\t\t\t\t{app_group_id} /* {APP_NAME} */,\n"
        f"\t\t\t\t{products_group_id} /* Products */,\n"
        f"\t\t\t);\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};"
    )
    out.append(
        f"\t\t{products_group_id} /* Products */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n\t\t\t\t{product_id} /* {APP_NAME}.app */,\n\t\t\t);\n"
        f"\t\t\tname = Products;\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};"
    )
    out.extend(group_lines)
    out.append("/* End PBXGroup section */")
    out.append("")

    # --- Target -------------------------------------------------------------
    out.append("/* Begin PBXNativeTarget section */")
    out.append(
        f"\t\t{target_id} /* {APP_NAME} */ = {{\n"
        f"\t\t\tisa = PBXNativeTarget;\n"
        f"\t\t\tbuildConfigurationList = {target_config_list_id};\n"
        f"\t\t\tbuildPhases = (\n"
        f"\t\t\t\t{sources_phase_id} /* Sources */,\n"
        f"\t\t\t\t{frameworks_phase_id} /* Frameworks */,\n"
        f"\t\t\t\t{resources_phase_id} /* Resources */,\n"
        f"\t\t\t);\n"
        f"\t\t\tbuildRules = (\n\t\t\t);\n"
        f"\t\t\tdependencies = (\n\t\t\t);\n"
        f"\t\t\tname = {APP_NAME};\n"
        f"\t\t\tproductName = {APP_NAME};\n"
        f"\t\t\tproductReference = {product_id} /* {APP_NAME}.app */;\n"
        f"\t\t\tproductType = \"com.apple.product-type.application\";\n"
        f"\t\t}};"
    )
    out.append("/* End PBXNativeTarget section */")
    out.append("")

    # --- Progetto -----------------------------------------------------------
    out.append("/* Begin PBXProject section */")
    out.append(
        f"\t\t{project_id} /* Project object */ = {{\n"
        f"\t\t\tisa = PBXProject;\n"
        f"\t\t\tattributes = {{\n"
        f"\t\t\t\tBuildIndependentTargetsInParallel = 1;\n"
        f"\t\t\t\tLastSwiftUpdateCheck = 1520;\n"
        f"\t\t\t\tLastUpgradeCheck = 1520;\n"
        f"\t\t\t\tTargetAttributes = {{\n"
        f"\t\t\t\t\t{target_id} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.2;\n\t\t\t\t\t}};\n"
        f"\t\t\t\t}};\n"
        f"\t\t\t}};\n"
        f"\t\t\tbuildConfigurationList = {project_config_list_id};\n"
        f"\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n"
        f"\t\t\tdevelopmentRegion = it;\n"
        f"\t\t\thasScannedForEncodings = 0;\n"
        f"\t\t\tknownRegions = (\n\t\t\t\tit,\n\t\t\t\tBase,\n\t\t\t);\n"
        f"\t\t\tmainGroup = {main_group_id};\n"
        f"\t\t\tproductRefGroup = {products_group_id} /* Products */;\n"
        f"\t\t\tprojectDirPath = \"\";\n"
        f"\t\t\tprojectRoot = \"\";\n"
        f"\t\t\ttargets = (\n\t\t\t\t{target_id} /* {APP_NAME} */,\n\t\t\t);\n"
        f"\t\t}};"
    )
    out.append("/* End PBXProject section */")
    out.append("")

    # --- Resources ----------------------------------------------------------
    resource_entries = "\n".join(
        f"\t\t\t\t{uid('build', str(path))} /* {path.name} in Resources */,"
        for path in copied_resources
    )
    out.append("/* Begin PBXResourcesBuildPhase section */")
    out.append(
        f"\t\t{resources_phase_id} /* Resources */ = {{\n"
        f"\t\t\tisa = PBXResourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n{resource_entries}\n\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};"
    )
    out.append("/* End PBXResourcesBuildPhase section */")
    out.append("")

    # --- Sources ------------------------------------------------------------
    source_entries = "\n".join(
        f"\t\t\t\t{uid('build', str(path))} /* {path.name} in Sources */,"
        for path in sources
    )
    out.append("/* Begin PBXSourcesBuildPhase section */")
    out.append(
        f"\t\t{sources_phase_id} /* Sources */ = {{\n"
        f"\t\t\tisa = PBXSourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n{source_entries}\n\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};"
    )
    out.append("/* End PBXSourcesBuildPhase section */")
    out.append("")

    # --- Configurazioni -----------------------------------------------------
    out.append("/* Begin XCBuildConfiguration section */")
    out.append(project_configuration("Debug", uid("config", "project", "Debug")))
    out.append(project_configuration("Release", uid("config", "project", "Release")))
    out.append(target_configuration("Debug", uid("config", "target", "Debug")))
    out.append(target_configuration("Release", uid("config", "target", "Release")))
    out.append("/* End XCBuildConfiguration section */")
    out.append("")

    out.append("/* Begin XCConfigurationList section */")
    for list_id, scope in ((project_config_list_id, "project"), (target_config_list_id, "target")):
        out.append(
            f"\t\t{list_id} = {{\n"
            f"\t\t\tisa = XCConfigurationList;\n"
            f"\t\t\tbuildConfigurations = (\n"
            f"\t\t\t\t{uid('config', scope, 'Debug')} /* Debug */,\n"
            f"\t\t\t\t{uid('config', scope, 'Release')} /* Release */,\n"
            f"\t\t\t);\n"
            f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
            f"\t\t\tdefaultConfigurationName = Release;\n"
            f"\t\t}};"
        )
    out.append("/* End XCConfigurationList section */")
    out.append("")

    out.append("\t};")
    out.append(f"\trootObject = {project_id} /* Project object */;")
    out.append("}")

    PROJECT_DIR.mkdir(parents=True, exist_ok=True)
    (PROJECT_DIR / "project.pbxproj").write_text("\n".join(out) + "\n", encoding="utf-8")

    write_scheme()
    return len(sources), len(copied_resources)


def settings_block(pairs):
    return "\n".join(f"\t\t\t\t{key} = {value};" for key, value in pairs)


def project_configuration(name, config_id):
    is_debug = name == "Debug"
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
            ("ENABLE_TESTABILITY", "YES"),
            ("GCC_DYNAMIC_NO_PIC", "NO"),
            ("GCC_OPTIMIZATION_LEVEL", "0"),
            ("GCC_PREPROCESSOR_DEFINITIONS", '(\n\t\t\t\t\t"DEBUG=1",\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t)'),
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

    return (
        f"\t\t{config_id} /* {name} */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbuildSettings = {{\n{settings_block(sorted(pairs))}\n\t\t\t}};\n"
        f"\t\t\tname = {name};\n"
        f"\t\t}};"
    )


def target_configuration(name, config_id):
    pairs = [
        ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
        ("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "AccentColor"),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("CURRENT_PROJECT_VERSION", "1"),
        ("DEVELOPMENT_ASSET_PATHS", '""'),
        ("ENABLE_PREVIEWS", "YES"),
        ("GENERATE_INFOPLIST_FILE", "NO"),
        ("INFOPLIST_FILE", f"{APP_NAME}/App/Info.plist"),
        ("LD_RUNPATH_SEARCH_PATHS", '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t)'),
        ("MARKETING_VERSION", "1.0"),
        ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID),
        ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
        ("SWIFT_EMIT_LOC_STRINGS", "YES"),
        ("SWIFT_VERSION", SWIFT_VERSION),
        # 1 = solo iPhone. È la riga che rende l'app "iPhone only".
        ("TARGETED_DEVICE_FAMILY", "1"),
    ]

    return (
        f"\t\t{config_id} /* {name} */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbuildSettings = {{\n{settings_block(sorted(pairs))}\n\t\t\t}};\n"
        f"\t\t\tname = {name};\n"
        f"\t\t}};"
    )


def write_scheme():
    """Lo schema condiviso: senza, Xcode ne crea uno al volo che non finisce su git."""
    scheme_dir = PROJECT_DIR / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)

    target_id = uid("target", APP_NAME)
    project_id_ref = f"{APP_NAME}.xcodeproj"

    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1520" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target_id}"
               BuildableName = "{APP_NAME}.app"
               BlueprintName = "{APP_NAME}"
               ReferencedContainer = "container:{project_id_ref}">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{APP_NAME}.app"
            BlueprintName = "{APP_NAME}"
            ReferencedContainer = "container:{project_id_ref}">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target_id}"
            BuildableName = "{APP_NAME}.app"
            BlueprintName = "{APP_NAME}"
            ReferencedContainer = "container:{project_id_ref}">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    (scheme_dir / f"{APP_NAME}.xcscheme").write_text(scheme, encoding="utf-8")


if __name__ == "__main__":
    source_count, resource_count = generate()
    print(f"{PROJECT_DIR.name} generato: {source_count} sorgenti, {resource_count} risorse.")
