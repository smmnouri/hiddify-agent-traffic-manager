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
    # Find extensions.extend([ pattern - be careful with indentation
    extensions_pattern = r"(extensions\.extend\(\[)"
    if re.search(extensions_pattern, content):
        # Find the indentation of the line before extensions.extend
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if 'extensions.extend([' in line:
                # Get indentation from previous line or current line
                if i > 0:
                    prev_line = lines[i-1]
                    indent = len(prev_line) - len(prev_line.lstrip())
                    if indent == 0:
                        # Use current line indentation
                        indent = len(line) - len(line.lstrip())
                else:
                    indent = len(line) - len(line.lstrip())
                
                # Add with correct indentation
                indent_str = ' ' * (indent + 4)
                replacement = f'{line}\n{indent_str}"hiddify_agent_traffic_manager:init_app",'
                content = '\n'.join(lines[:i]) + '\n' + replacement + '\n' + '\n'.join(lines[i+1:])
                print("Added to extensions list")
                break
    
    # Method 2: Add import and call init_app
    # Add import after other imports
    import_pattern = r'(from dynaconf import FlaskDynaconf\n)'
    if re.search(import_pattern, content):
        replacement = r'\1from hiddify_agent_traffic_manager import init_app\n'
        content = re.sub(import_pattern, replacement, content)
        print("Added import")
    
    # Add init_app call before return app - be careful with indentation
    return_pattern = r'(\s+return app\n)'
    if re.search(return_pattern, content) and 'app = init_app(app)' not in content:
        # Get indentation from return statement
        match = re.search(return_pattern, content)
        if match:
            indent = len(match.group(1)) - len('return app\n')
            indent_str = ' ' * indent
            replacement = f'{indent_str}app = init_app(app)\n{match.group(1)}'
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

