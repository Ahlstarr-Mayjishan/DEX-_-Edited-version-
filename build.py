import os

def lua_long_string(value):
    level = 0
    while "]" + ("=" * level) + "]" in value:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{value}\n]{eq}]"

def build():
    print("Building DEX++_compiled.luau...")
    
    # Read the hollow shell
    shell_path = "DEX++.luau"
    if not os.path.exists(shell_path):
        print(f"Error: Hollow shell '{shell_path}' not found!")
        return

    with open(shell_path, "r", encoding="utf-8") as f:
        template = f.read()

    # Load module files and format them for insertion
    module_list = [
        "Theme", "SmartDecompiler", "Console", "Explorer", "Lib", "ModelViewer", 
        "Properties", "SaveInstance", "ScriptViewer", "SettingsWindow", "CodeSearch", "ScriptRelations", "RemoteUsageMap", "ObjectLinks", "ImageViewer", "ClientIndex", "ActivityMap", "DependencyGraph", "SmartSearch", "RuntimeInspector", "SecurityAuditor", "ClientIntelligence", "InspectorHub", "TaskRouter", "RemoteFuzzer", "PropertyTracker", "InstanceSerializer", "ThreadManager"
    ]
    
    embedded_str = ""
    for name in module_list:
        filepath = os.path.join("Modules", f"{name}.luau")
        if not os.path.exists(filepath):
            filepath = os.path.join("Modules", f"{name}.lua")
            
        with open(filepath, "r", encoding="utf-8") as mf:
            m_code = mf.read().strip()
        
        # Indent the module code for clean formatting inside EmbeddedModules
        indented_code = "\n".join("    " + line for line in m_code.splitlines())
        embedded_str += f'["{name}"] = function()\n{indented_code}\nend,\n'

    plugin_entries = []
    plugin_dir = "Plugins"
    if os.path.isdir(plugin_dir):
        for filename in sorted(os.listdir(plugin_dir)):
            if not (filename.endswith(".luau") or filename.endswith(".lua")):
                continue
            plugin_path = os.path.join(plugin_dir, filename)
            with open(plugin_path, "r", encoding="utf-8") as pf:
                plugin_code = pf.read().strip()
            out_name = os.path.splitext(filename)[0] + ".lua"
            plugin_entries.append(f'["{out_name}"] = {lua_long_string(plugin_code)},')

    # Replace placeholders
    compiled = template.replace("-- [[EMBEDDED_MODULES_PLACEHOLDER]]", embedded_str.strip())
    compiled = compiled.replace("-- [[PLUGIN_SOURCES_PLACEHOLDER]]", "\n\t".join(plugin_entries))

    with open("DEX++_compiled.luau", "w", encoding="utf-8") as out:
        out.write(compiled)
    print("Built DEX++_compiled.luau successfully!")

if __name__ == "__main__":
    build()
