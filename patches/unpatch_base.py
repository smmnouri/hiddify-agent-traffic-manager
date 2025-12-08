#!/usr/bin/env python3
"""
Remove patches from base.py
"""
import sys
import re
from pathlib import Path

def unpatch_base(file_path):
    """Remove patches from base.py"""
    
    if not Path(file_path).exists():
        print(f"Error: File not found: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Remove import
    content = re.sub(r'from hiddify_agent_traffic_manager import init_app\n', '', content)
    
    # Remove from extensions list
    content = re.sub(r'\s+"hiddify_agent_traffic_manager:init_app",\n', '', content)
    
    # Remove init_app call
    content = re.sub(r'\s+app = init_app\(app\)\n', '', content)
    
    if content == original_content:
        print("No patches found to remove")
        return False
    
    # Write the unpatched content
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Successfully removed patches from: {file_path}")
    return True

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python unpatch_base.py <path_to_base.py>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    success = unpatch_base(file_path)
    sys.exit(0 if success else 1)

