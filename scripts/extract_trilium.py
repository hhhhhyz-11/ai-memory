#!/usr/bin/env python3
import re
import os
import subprocess

# Read the trilium backup
with open('memory/trilium_backup.md', 'r', encoding='utf-8') as f:
    content = f.read()

# Find all section headers (## root/...)
sections = re.split(r'\n(?=## root/)', content)

# Skip the first section (navigation)
notes = [s for s in sections if s.startswith('## root/')]

def slugify(title):
    """Convert title to filename-safe string"""
    title = title.replace(' ', '-')
    title = re.sub(r'[^\w\-\u4e00-\u9fff]', '', title)  # keep Chinese
    title = re.sub(r'-+', '-', title)
    return title.strip('-')

def extract_content(section):
    """Extract title and HTML content from section"""
    lines = section.split('\n')
    title_line = lines[0].replace('## ', '').strip()
    
    # Find where actual content starts (after the HTML file reference line)
    content_lines = []
    in_content = False
    for line in lines[1:]:
        if line.startswith('📄 文件:'):
            in_content = True
            continue
        if in_content:
            content_lines.append(line)
    
    return title_line, '\n'.join(content_lines)

def html_to_markdown(html_content):
    """Basic HTML to Markdown conversion"""
    md = html_content
    
    # Remove HTML comments
    md = re.sub(r'<!--.*?-->', '', md, flags=re.DOTALL)
    
    # Remove div/spans with class/style
    md = re.sub(r'<div[^>]*>', '\n', md)
    md = re.sub(r'</div>', '', md)
    md = re.sub(r'<span[^>]*>', '', md)
    md = re.sub(r'</span>', '', md)
    
    # Headers
    md = re.sub(r'<h2[^>]*>(.*?)</h2>', r'\n## \1\n', md, flags=re.DOTALL)
    md = re.sub(r'<h3[^>]*>(.*?)</h3>', r'\n### \1\n', md, flags=re.DOTALL)
    md = re.sub(r'<h4[^>]*>(.*?)</h4>', r'\n#### \1\n', md, flags=re.DOTALL)
    md = re.sub(r'<strong[^>]*>(.*?)</strong>', r'**\1**', md, flags=re.DOTALL)
    md = re.sub(r'<b[^>]*>(.*?)</b>', r'**\1**', md, flags=re.DOTALL)
    md = re.sub(r'<em[^>]*>(.*?)</em>', r'*\1*', md, flags=re.DOTALL)
    
    # Code blocks
    md = re.sub(r'<pre[^>]*>(.*?)</pre>', r'\n```\n\1\n```\n', md, flags=re.DOTALL)
    md = re.sub(r'<code[^>]*>(.*?)</code>', r'`\1`', md, flags=re.DOTALL)
    
    # Links
    md = re.sub(r'<a[^>]*href=["\']([^"\']*)["\'][^>]*>(.*?)</a>', r'[\2](\1)', md, flags=re.DOTALL)
    
    # Lists
    md = re.sub(r'<li[^>]*>(.*?)</li>', r'- \1\n', md, flags=re.DOTALL)
    md = re.sub(r'<ul[^>]*>', '\n', md)
    md = re.sub(r'</ul>', '', md)
    md = re.sub(r'<ol[^>]*>', '\n', md)
    md = re.sub(r'</ol>', '', md)
    
    # Line breaks and paragraphs
    md = re.sub(r'<br\s*/?>', '\n', md)
    md = re.sub(r'<p[^>]*>', '\n', md)
    md = re.sub(r'</p>', '', md)
    
    # Clean up extra whitespace
    md = re.sub(r'\n{3,}', '\n\n', md)
    md = md.strip()
    
    return md

def extract_title_from_html(html):
    """Extract title from HTML content (first h2)"""
    match = re.search(r'<h2[^>]*>(.*?)</h2>', html, flags=re.DOTALL)
    if match:
        title = re.sub(r'<[^>]+>', '', match.group(1))
        return title.strip()
    # fallback: first non-empty line
    for line in html.split('\n'):
        line = line.strip()
        if line and not line.startswith('<') and len(line) > 2:
            return line[:50]
    return 'untitled'

print(f"Found {len(notes)} notes")

# Output directories
ops_dir = '运维事项'
docs_dir = 'docs'
os.makedirs(ops_dir, exist_ok=True)
os.makedirs(docs_dir, exist_ok=True)

# Category mapping
OPS_NOTES = [
    '部署文档', '数据备份', 'Jenkins流水线', 
    'linux服务器配置jdk变量', 'k8s命令', 'WSL', 'rsync',
    'Gitlab+Gitlab-runner+sonarqube', 'openclaw笔记',
    '基于Squid代理服务器实现外网代理'
]

for note in notes:
    title, raw_content = extract_content(note)
    
    # Extract HTML body content
    html_body = raw_content
    
    # Try to extract just the HTML content part (skip the file reference line)
    lines = note.split('\n')
    html_start = False
    html_lines = []
    for i, line in enumerate(lines):
        if '📄 文件:' in line:
            html_start = True
            continue
        if html_start:
            html_lines.append(line)
    
    html_body = '\n'.join(html_lines)
    
    # Extract title
    title_match = re.search(r'<h2[^>]*>(.*?)</h2>', html_body, flags=re.DOTALL)
    if title_match:
        display_title = re.sub(r'<[^>]+>', '', title_match.group(1)).strip()
    else:
        display_title = title.replace('root/', '').replace('/', '-')
    
    # Convert to markdown
    md_content = html_to_markdown(html_body)
    
    # Determine destination
    filename_base = slugify(display_title)[:60]
    
    # Check category
    is_ops = any(cat in title for cat in OPS_NOTES)
    
    if is_ops:
        dest_dir = ops_dir
    else:
        dest_dir = docs_dir
    
    # Find a good filename
    filename = f"{filename_base}.md"
    dest_path = os.path.join(dest_dir, filename)
    
    # Avoid overwriting existing files
    counter = 1
    while os.path.exists(dest_path):
        filename = f"{filename_base}-{counter}.md"
        dest_path = os.path.join(dest_dir, filename)
        counter += 1
    
    # Write file
    with open(dest_path, 'w', encoding='utf-8') as f:
        f.write(f"# {display_title}\n\n")
        f.write(f"> 来源: Trilium Notes 导出\n\n")
        f.write(md_content)
        f.write('\n')
    
    print(f"✓ {title} -> {dest_path}")

print("\nDone!")
