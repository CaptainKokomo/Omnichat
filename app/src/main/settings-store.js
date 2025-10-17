const fs = require('fs');
const path = require('path');
const { app } = require('electron');

class SettingsStore {
  constructor({ name = 'settings.json', defaults = {} } = {}) {
    this.name = name;
    this.defaults = defaults;
    this.filePath = path.join(app.getPath('userData'), name);
    this._data = null;
  }

  load() {
    if (this._data) {
      return this._data;
    }
    try {
      const raw = fs.readFileSync(this.filePath, 'utf8');
      this._data = JSON.parse(raw);
    } catch (err) {
      this._data = { ...this.defaults };
      this.save(this._data);
    }
    return this._data;
  }

  get(key) {
    const data = this.load();
    return data[key];
  }

  set(key, value) {
    const data = this.load();
    data[key] = value;
    this.save(data);
  }

  save(newData) {
    this._data = { ...this.defaults, ...newData };
    fs.writeFileSync(this.filePath, JSON.stringify(this._data, null, 2), 'utf8');
  }

  get all() {
    return this.load();
  }

  set all(newData) {
    this.save(newData);
  }
}

module.exports = { SettingsStore };
