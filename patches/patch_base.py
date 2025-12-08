#!/usr/bin/env python3
"""
Patch script for base.py
Adds hiddify_agent_traffic_manager to extensions or calls init_app
"""
import sys
import re
from pathlib import Path

def patch_base(file_path):
    """Apply patches to base.py"""
    
    if not Path(file_path).exists():
        print(f"Error: File not found: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Check if already patched
    if 'hiddify_agent_traffic_manager' in content:
        print("Already patched (hiddify_agent_traffic_manager found)")
        return True
    
    # Method 1: Add to extensions list
    # Find extensions.extend([ pattern
    extensions_pattern = r"(extensions\.extend\(\[)"
    if re.search(extensions_pattern, content):
        # Add after other extensions
        replacement = r'\1\n            "hiddify_agent_traffic_manager:init_app",'
        content = re.sub(extensions_pattern, replacement, content, count=1)
        print("Added to extensions list")
    
    # Method 2: Add import and call init_app
    # Add import after other imports
    import_pattern = r'(from dynaconf import FlaskDynaconf\n)'
    if re.search(import_pattern, content):
        replacement = r'\1from hiddify_agent_traffic_manager import init_app\n'
        content = re.sub(import_pattern, replacement, content)
        print("Added import")
    
    # Add init_app call before return app
    return_pattern = r'(\s+return app\n)'
    if re.search(return_pattern, content) and 'app = init_app(app)' not in content:
        replacement = r'    app = init_app(app)\n\1'
        content = re.sub(return_pattern, replacement, content, count=1)
        print("Added init_app call")
    
    # Check if any changes were made
    if content == original_content:
        print("Warning: No changes were made. File might already be patched or structure is different.")
        return False
    
    # Write the patched content
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Successfully patched: {file_path}")
    return True

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python patch_base.py <path_to_base.py>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    success = patch_base(file_path)
    sys.exit(0 if success else 1)

