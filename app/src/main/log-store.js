const { app } = require('electron');
const fs = require('fs');
const path = require('path');

class LogStore {
  constructor() {
    this.entries = [];
  }

  append(entry) {
    const enriched = {
      timestamp: new Date().toISOString(),
      ...entry
    };
    this.entries.push(enriched);
  }

  getEntries() {
    return this.entries.slice(-500);
  }

  serialize() {
    return this.entries
      .map((entry) => `${entry.timestamp}\t${entry.type.toUpperCase()}\t${entry.message}`)
      .join('\n');
  }

  exportToFile(filename = 'Omnichat-log.txt') {
    const exportPath = path.join(app.getPath('documents'), filename);
    fs.writeFileSync(exportPath, this.serialize(), 'utf8');
    return exportPath;
  }
}

module.exports = { LogStore };
