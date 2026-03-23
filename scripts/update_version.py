import sys
import re
import os

def update_version(new_version_full):
    if '+' not in new_version_full:
        print("Error: Version must be in format x.y.z+b")
        sys.exit(1)
    
    version, build_number = new_version_full.split('+')
    
    # Update pubspec.yaml
    pubspec_path = 'pubspec.yaml'
    if os.path.exists(pubspec_path):
        with open(pubspec_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Match 'version: x.y.z+b'
        pubspec_pattern = r'version: \d+\.\d+\.\d+\+\d+'
        if not re.search(pubspec_pattern, content):
            print(f"Warning: Could not find version pattern in {pubspec_path}")
        
        new_content = re.sub(pubspec_pattern, f'version: {new_version_full}', content)
        
        with open(pubspec_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"✅ Updated {pubspec_path} to {new_version_full}")
    else:
        print(f"Error: {pubspec_path} not found")
        sys.exit(1)

    # Update lib/configs/app_config.dart
    app_config_path = 'lib/configs/app_config.dart'
    if os.path.exists(app_config_path):
        with open(app_config_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Replace version: final String version = '1.0.0';
        version_pattern = r"final String version = '.*?';"
        if not re.search(version_pattern, content):
            print(f"Warning: Could not find version variable in {app_config_path}")
        new_content = re.sub(version_pattern, f"final String version = '{version}';", content)
        
        # Replace buildNumber: final String buildNumber = '2';
        build_number_pattern = r"final String buildNumber = '.*?';"
        if not re.search(build_number_pattern, new_content):
            print(f"Warning: Could not find buildNumber variable in {app_config_path}")
        new_content = re.sub(build_number_pattern, f"final String buildNumber = '{build_number}';", new_content)
        
        with open(app_config_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"✅ Updated {app_config_path} to version: {version}, buildNumber: {build_number}")
    else:
        print(f"Error: {app_config_path} not found")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 scripts/update_version.py x.y.z+b")
        sys.exit(1)
    
    update_version(sys.argv[1])
