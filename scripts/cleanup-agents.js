const fs = require('fs');

const config = JSON.parse(fs.readFileSync('/root/.openclaw/openclaw.json', 'utf8'));

// 运维技术相关关键词
const keepPrefixes = [
  'main',
  'engineering-',
  'testing-',
  'project-management-jira',
  'project-management-experiment',
  'project-management-studio',
  'project-management-project',
  'lsp-index',
  'specialized-mcp',
  'specialized-model-qa',
  'specialized-document',
  'report-distribution',
  'supply-chain-vendor',
  'supply-chain-route',
  'supply-chain-inventory',
];

function shouldKeep(id) {
  return keepPrefixes.some(prefix => id === prefix || id.startsWith(prefix));
}

const originalCount = config.agents.list.length;
config.agents.list = config.agents.list.filter(a => shouldKeep(a.id));
const removedCount = originalCount - config.agents.list.length;

console.log(`保留: ${config.agents.list.length}, 删除: ${removedCount}`);
console.log('保留列表:', config.agents.list.map(a => a.id).join(', '));

fs.writeFileSync('/root/.openclaw/openclaw.json', JSON.stringify(config, null, 2));
console.log('已写入 /root/.openclaw/openclaw.json');
