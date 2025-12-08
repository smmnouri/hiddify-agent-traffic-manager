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
    
    # Remove old patches first (in case of re-patching)
    # Use line-by-line removal to preserve file structure
    lines = content.split('\n')
    new_lines = []
    skip_next = False
    
    for i, line in enumerate(lines):
        # Skip lines that are part of old patches
        if 'from hiddify_agent_traffic_manager import init_app' in line:
            continue
        if '"hiddify_agent_traffic_manager:init_app"' in line:
            continue
        if 'app = init_app(app)' in line and 'hiddify_agent_traffic_manager' in '\n'.join(lines[max(0, i-5):i]):
            continue
        
        new_lines.append(line)
    
    content = '\n'.join(new_lines)
    
    # Check if already patched (after cleanup)
    if 'hiddify_agent_traffic_manager' in content:
        print("Warning: Still found hiddify_agent_traffic_manager after cleanup, proceeding anyway...")
    
    # Method 1: Add to extensions list
    # Find extensions.extend([ pattern - be careful with indentation
    lines = content.split('\n')
    patched = False
    
    for i, line in enumerate(lines):
        if 'extensions.extend([' in line:
            # Get indentation from current line
            indent = len(line) - len(line.lstrip())
            indent_str = ' ' * (indent + 4)
            
            # Find where to insert (before the closing bracket)
            insert_pos = i + 1
            for j in range(i + 1, min(i + 20, len(lines))):
                if '])' in lines[j]:
                    # Insert before the closing bracket line
                    insert_pos = j
                    break
                elif lines[j].strip() == ']':
                    # Insert before the closing bracket line
                    insert_pos = j
                    break
                elif lines[j].strip().startswith('"') or lines[j].strip().startswith("'"):
                    # Keep track of the last item
                    insert_pos = j + 1
                    continue
            
            # Insert the new extension
            new_line = f'{indent_str}"hiddify_agent_traffic_manager:init_app",'
            lines.insert(insert_pos, new_line)
            content = '\n'.join(lines)
            print("Added to extensions list")
            patched = True
            break
    
    # Method 2: Add import and call init_app (only if Method 1 didn't work)
    if not patched:
        # Add import after other imports
        import_pattern = r'(from dynaconf import FlaskDynaconf\n)'
        if re.search(import_pattern, content):
            replacement = r'\1from hiddify_agent_traffic_manager import init_app\n'
            content = re.sub(import_pattern, replacement, content)
            print("Added import")
        
        # Add init_app call before return app - be careful with indentation
        if 'app = init_app(app)' not in content:
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if line.strip() == 'return app':
                    # Get indentation from return statement
                    indent = len(line) - len(line.lstrip())
                    indent_str = ' ' * indent
                    # Insert before return
                    lines.insert(i, f'{indent_str}app = init_app(app)')
                    content = '\n'.join(lines)
                    print("Added init_app call")
                    patched = True
                    break
    
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

