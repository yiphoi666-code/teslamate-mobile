const db = require('./db');

const REQUIRED_TABLES = [
  'cars',
  'positions',
  'drives',
  'charging_processes',
  'charges',
  'geofences',
  'addresses',
  'settings',
];

const CORE_COLUMNS = {
  cars: [['id'], ['name']],
  positions: [
    ['id'],
    ['car_id'],
    ['date'],
    ['latitude'],
    ['longitude'],
    ['battery_level'],
    ['odometer'],
  ],
  drives: [
    ['id'],
    ['car_id'],
    ['start_date'],
    ['end_date'],
    ['start_position_id'],
    ['end_position_id'],
    ['start_address_id'],
    ['end_address_id'],
    ['distance'],
    ['start_rated_range_km'],
    ['end_rated_range_km'],
    ['start_ideal_range_km'],
    ['end_ideal_range_km'],
  ],
  addresses: [['id']],
  settings: [['preferred_range']],
  charging_processes: [['id'], ['car_id'], ['start_date'], ['end_date']],
  charges: [
    ['id'],
    ['charging_process_id'],
    ['date'],
    ['battery_level'],
    ['charge_energy_added'],
    ['charger_power'],
  ],
  geofences: [['id'], ['name']],
};

async function getSchemaDiagnostics() {
  const connection = await db.checkConnection();
  if (!connection.connected) {
    return {
      status: 'database_unreachable',
      connection,
      tables: [],
      missingTables: REQUIRED_TABLES,
      missingColumns: CORE_COLUMNS,
      warnings: [
        'Reader API is running, but PostgreSQL is not reachable with the current .env settings.',
      ],
    };
  }

  const schemaRows = await loadPublicSchema();
  const byTable = groupColumnsByTable(schemaRows);
  const missingTables = REQUIRED_TABLES.filter((table) => !byTable.has(table));
  const missingColumns = {};

  for (const [table, columnGroups] of Object.entries(CORE_COLUMNS)) {
    if (!byTable.has(table)) {
      continue;
    }

    const tableColumns = byTable.get(table);
    const missingGroups = columnGroups.filter(
      (alternatives) => !alternatives.some((column) => tableColumns.has(column))
    );
    if (missingGroups.length > 0) {
      missingColumns[table] = missingGroups;
    }
  }

  const tableRows = await Promise.all(
    REQUIRED_TABLES.map(async (table) => ({
      name: table,
      exists: byTable.has(table),
      columns: byTable.has(table) ? [...byTable.get(table)].sort() : [],
      rowCount: byTable.has(table) ? await safeCountRows(table) : 0,
    }))
  );

  const status =
    missingTables.length === 0 && Object.keys(missingColumns).length === 0
      ? 'ready'
      : 'schema_attention_required';

  return {
    status,
    connection,
    tables: tableRows,
    missingTables,
    missingColumns,
    warnings: buildWarnings(missingTables, missingColumns),
  };
}

async function loadPublicSchema() {
  const result = await db.query(`
    select table_name, column_name, data_type
    from information_schema.columns
    where table_schema = 'public'
    order by table_name, ordinal_position
  `);
  return result.rows;
}

function groupColumnsByTable(rows) {
  const byTable = new Map();
  for (const row of rows) {
    if (!byTable.has(row.table_name)) {
      byTable.set(row.table_name, new Set());
    }
    byTable.get(row.table_name).add(row.column_name);
  }
  return byTable;
}

async function safeCountRows(table) {
  try {
    const result = await db.one(`select count(*)::int as count from ${table}`);
    return Number(result?.count || 0);
  } catch (_error) {
    return 0;
  }
}

function buildWarnings(missingTables, missingColumns) {
  const warnings = [];
  if (missingTables.length > 0) {
    warnings.push(`Missing tables: ${missingTables.join(', ')}`);
  }

  for (const [table, groups] of Object.entries(missingColumns)) {
    const names = groups.map((group) => group.join(' or ')).join(', ');
    warnings.push(`Table ${table} is missing expected columns: ${names}`);
  }

  if (warnings.length === 0) {
    warnings.push('TeslaMate core schema looks compatible with the current Reader API.');
  }

  return warnings;
}

module.exports = {
  getSchemaDiagnostics,
};
