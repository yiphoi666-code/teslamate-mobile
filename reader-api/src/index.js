const cors = require('cors');
const express = require('express');

const { requireBearerToken } = require('./auth');
const config = require('./config');
const db = require('./db');
const { getSchemaDiagnostics } = require('./diagnostics');
const logger = require('./logger');
const { mapCharge, mapDrive, numberFrom } = require('./mapper');

const app = express();
const READER_API_VERSION = '0.4.6';
const DEFAULT_RAW_LIMIT = 200;
const MAX_RAW_LIMIT = 1000;

app.use(cors());
app.use(express.json());
app.use(logger.apiLogger);

app.get('/api/ping', async (_req, res) => {
  res.json({
    status: 'ok',
    version: READER_API_VERSION,
    tokenEnabled: Boolean(config.token),
  });
});

app.get('/api/health', async (_req, res) => {
  const database = await db.checkConnection();
  res.json({
    status: database.connected ? 'ok' : 'degraded',
    version: READER_API_VERSION,
    database,
    config: {
      usingDatabaseUrl: config.usingDatabaseUrl,
      host: config.usingDatabaseUrl ? 'DATABASE_URL' : config.databaseHost,
      port: config.usingDatabaseUrl ? null : config.databasePort,
      database: config.usingDatabaseUrl ? null : config.databaseName,
      user: config.usingDatabaseUrl ? null : config.databaseUser,
      tokenEnabled: Boolean(config.token),
    },
  });
});

app.use('/api', requireBearerToken);

app.get('/api/auth/check', async (_req, res) => {
  res.json({
    status: 'ok',
    version: READER_API_VERSION,
    tokenAccepted: true,
  });
});

app.get('/api/diagnostics/schema', async (_req, res, next) => {
  try {
    res.json(await getSchemaDiagnostics());
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars', async (_req, res, next) => {
  try {
    const result = await db.query(`
      select *
      from cars
      order by id
    `);
    res.json(
      result.rows.map((row) => ({
        id: row.id,
        name: row.name || `Car ${row.id}`,
        model: row.model || 'Tesla',
      }))
    );
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars/:carId/summary', async (req, res, next) => {
  try {
    const carId = Number(req.params.carId);
    const [car, position, monthlyStats, database, dataQuality] = await Promise.all([
      getCar(carId),
      getLatestPosition(carId),
      getMonthlyStats(carId),
      getDatabaseInfo(),
      getDataQuality(carId),
    ]);
    const resolvedDataQuality = {
      ...dataQuality,
      lastHealthyAt: dataQuality.lastHealthyAt || database.latestDataAt,
    };

    res.json({
      vehicle: mapVehicle(car, position),
      monthlyStats,
      locations: buildLocations(car, position, []),
      database,
      analytics: buildAnalytics(monthlyStats, [], [], database, {
        car,
        position,
        dataQuality: resolvedDataQuality,
      }),
    });
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars/:carId/overview', async (req, res, next) => {
  try {
    const carId = Number(req.params.carId);
    const [
      car,
      position,
      drives,
      charges,
      monthlyStats,
      database,
      stateTimeline,
      monthlyMileage,
      rangeDegradation,
      chargingCurves,
      speedRates,
      speedTemperature,
      topStations,
      dataQuality,
    ] = await Promise.all([
      getCar(carId),
      getLatestPosition(carId),
      getRecentDrives(carId, 25),
      getRecentCharges(carId, 25),
      getMonthlyStats(carId),
      getDatabaseInfo(),
      getStateTimeline(carId),
      getMonthlyMileage(carId),
      getRangeDegradation(carId),
      getChargingCurves(carId),
      getSpeedRates(carId),
      getSpeedTemperature(carId),
      getTopStations(carId),
      getDataQuality(carId),
    ]);

    const mappedDrives = drives.map((row) => mapDrive(row));
    const mappedCharges = charges.map((row) => mapCharge(row));
    const resolvedDataQuality = {
      ...dataQuality,
      lastHealthyAt: dataQuality.lastHealthyAt || database.latestDataAt,
    };

    res.json({
      vehicle: mapVehicle(car, position),
      monthlyStats,
      drives: mappedDrives.slice(0, 10),
      charges: mappedCharges.slice(0, 10),
      locations: buildLocations(car, position, mappedCharges),
      database,
      analytics: buildAnalytics(monthlyStats, mappedDrives, mappedCharges, database, {
        car,
        position,
        stateTimeline,
        monthlyMileage,
        rangeDegradation,
        chargingCurves,
        speedRates,
        speedTemperature,
        topStations,
        dataQuality: resolvedDataQuality,
      }),
    });
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars/:carId/analytics', async (req, res, next) => {
  try {
    const carId = Number(req.params.carId);
    const [
      car,
      position,
      drives,
      charges,
      monthlyStats,
      database,
      stateTimeline,
      monthlyMileage,
      rangeDegradation,
      chargingCurves,
      speedRates,
      speedTemperature,
      topStations,
      dataQuality,
    ] = await Promise.all([
      getCar(carId),
      getLatestPosition(carId),
      getRecentDrives(carId, 25),
      getRecentCharges(carId, 25),
      getMonthlyStats(carId),
      getDatabaseInfo(),
      getStateTimeline(carId),
      getMonthlyMileage(carId),
      getRangeDegradation(carId),
      getChargingCurves(carId),
      getSpeedRates(carId),
      getSpeedTemperature(carId),
      getTopStations(carId),
      getDataQuality(carId),
    ]);
    const mappedDrives = drives.map((row) => mapDrive(row));
    const mappedCharges = charges.map((row) => mapCharge(row));
    const resolvedDataQuality = {
      ...dataQuality,
      lastHealthyAt: dataQuality.lastHealthyAt || database.latestDataAt,
    };

    res.json(
      buildAnalytics(monthlyStats, mappedDrives, mappedCharges, database, {
        car,
        position,
        stateTimeline,
        monthlyMileage,
        rangeDegradation,
        chargingCurves,
        speedRates,
        speedTemperature,
        topStations,
        dataQuality: resolvedDataQuality,
      })
    );
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars/:carId/drives', async (req, res, next) => {
  try {
    const carId = Number(req.params.carId);
    const limit = Math.min(Number(req.query.limit || 50), 200);
    const rows = await getRecentDrives(carId, limit);
    res.json(rows.map((row) => mapDrive(row)));
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars/:carId/drives/:driveId', async (req, res, next) => {
  try {
    const driveId = Number(req.params.driveId);
    const drive = await getDrive(driveId);
    if (!drive) {
      res.status(404).json({ error: 'drive_not_found' });
      return;
    }
    const tracking = await getDriveTrackingRows(driveId);
    res.json(mapDrive(drive, tracking.map(mapTrackingPoint)));
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars/:carId/drives/:driveId/tracking', async (req, res, next) => {
  try {
    const driveId = Number(req.params.driveId);
    const rows = await getDriveTrackingRows(driveId);
    res.json(rows.map(mapTrackingPoint));
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars/:carId/charging/sessions', async (req, res, next) => {
  try {
    const carId = Number(req.params.carId);
    const limit = Math.min(Number(req.query.limit || 50), 200);
    const rows = await getRecentCharges(carId, limit);
    res.json(rows.map((row) => mapCharge(row)));
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars/:carId/charging/sessions/:chargeId', async (req, res, next) => {
  try {
    const chargeId = Number(req.params.chargeId);
    const charge = await getCharge(chargeId);
    if (!charge) {
      res.status(404).json({ error: 'charge_not_found' });
      return;
    }
    const samples = await getChargeSamples(chargeId);
    res.json(mapCharge(charge, samples));
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars/:carId/visited-map', async (req, res, next) => {
  try {
    const carId = Number(req.params.carId);
    const rows = await db.query(
      `
        select drive_id, date, latitude, longitude
        from positions
        where car_id = $1
          and drive_id is not null
          and latitude is not null
          and longitude is not null
        order by drive_id desc, date asc
        limit 10000
      `,
      [carId]
    );
    const routes = [];
    const grouped = new Map();
    for (const row of rows.rows) {
      if (!grouped.has(row.drive_id)) {
        grouped.set(row.drive_id, []);
      }
      grouped.get(row.drive_id).push({
        latitude: Number(row.latitude),
        longitude: Number(row.longitude),
        label: new Date(row.date).toISOString(),
      });
    }
    for (const [driveId, points] of grouped.entries()) {
      routes.push({ driveId, points: downsample(points, 180) });
    }
    res.json({ routes });
  } catch (error) {
    next(error);
  }
});

app.get('/api/database/info', async (_req, res, next) => {
  try {
    res.json(await getDatabaseInfo());
  } catch (error) {
    next(error);
  }
});

app.get('/api/database/settings', async (_req, res, next) => {
  try {
    res.json(await getDatabaseSettings());
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars/:carId/data-quality', async (req, res, next) => {
  try {
    const carId = Number(req.params.carId);
    res.json(await getDataQuality(carId));
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars/:carId/database/tables', async (req, res, next) => {
  try {
    const carId = Number(req.params.carId);
    const definitions = await getVehicleTableDefinitions();
    const tables = await Promise.all(
      definitions.map((definition) => getVehicleTableMeta(definition, carId))
    );

    res.json({
      carId,
      pageSizeLimit: MAX_RAW_LIMIT,
      tables,
    });
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars/:carId/database/tables/:tableName', async (req, res, next) => {
  try {
    const carId = Number(req.params.carId);
    const definitions = await getVehicleTableDefinitions();
    const definition = definitions.find((item) => item.name === req.params.tableName);

    if (!definition) {
      res.status(404).json({
        error: 'vehicle_table_not_supported',
        message: 'This table is not known to contain data for the requested car.',
      });
      return;
    }

    res.json(await getVehicleTablePage(definition, carId, req.query));
  } catch (error) {
    next(error);
  }
});

app.get('/api/cars/:carId/database/export', async (req, res, next) => {
  try {
    const carId = Number(req.params.carId);
    const limitPerTable = boundedInt(req.query.limitPerTable, 100, MAX_RAW_LIMIT);
    const definitions = await getVehicleTableDefinitions();
    const tables = {};

    for (const definition of definitions) {
      tables[definition.name] = await getVehicleTablePage(definition, carId, {
        ...req.query,
        limit: limitPerTable,
        offset: 0,
      });
    }

    res.json({
      carId,
      limitPerTable,
      tables,
    });
  } catch (error) {
    next(error);
  }
});

app.use((error, req, res, _next) => {
  logger.error('api_request_failed', {
    requestId: req.requestId || null,
    method: req.method,
    path: req.path,
    error: error.message,
    stack: process.env.NODE_ENV === 'production' ? undefined : error.stack,
  });
  res.status(500).json({
    error: 'reader_api_error',
    message: error.message,
  });
});

app.listen(config.port, () => {
  logger.info('reader_api_started', {
    port: config.port,
    version: READER_API_VERSION,
    tokenEnabled: Boolean(config.token),
    database: config.usingDatabaseUrl ? 'DATABASE_URL' : config.databaseName,
  });
});

async function getCar(carId) {
  return db.one('select * from cars where id = $1', [carId]);
}

async function getLatestPosition(carId) {
  return db.one(
    `
      select *
      from positions
      where car_id = $1
      order by date desc
      limit 1
    `,
    [carId]
  );
}

async function getRecentDrives(carId, limit) {
  const result = await db.query(
    `
      select
        d.*,
        sp.latitude as start_latitude,
        sp.longitude as start_longitude,
        sp.battery_level as start_battery_level,
        ep.latitude as end_latitude,
        ep.longitude as end_longitude,
        ep.battery_level as end_battery_level,
        sg.name as start_geofence_name,
        eg.name as end_geofence_name,
        c.efficiency as car_efficiency,
        coalesce(
          sg.name,
          concat_ws(', ', coalesce(sa.name, nullif(concat_ws(' ', sa.road, sa.house_number), '')), sa.city),
          'Start'
        ) as start_address,
        coalesce(
          eg.name,
          concat_ws(', ', coalesce(ea.name, nullif(concat_ws(' ', ea.road, ea.house_number), '')), ea.city),
          'End'
        ) as end_address,
        greatest(
          coalesce(d.start_rated_range_km, sp.rated_battery_range_km, 0) -
            coalesce(d.end_rated_range_km, ep.rated_battery_range_km, 0),
          0
        ) as rated_range_diff_km,
        greatest(
          coalesce(d.start_ideal_range_km, sp.ideal_battery_range_km, 0) -
            coalesce(d.end_ideal_range_km, ep.ideal_battery_range_km, 0),
          0
        ) as ideal_range_diff_km,
        case
          when coalesce((select preferred_range from settings limit 1), 'rated') = 'ideal'
            then greatest(
              coalesce(d.start_ideal_range_km, sp.ideal_battery_range_km, 0) -
                coalesce(d.end_ideal_range_km, ep.ideal_battery_range_km, 0),
              0
            )
          else greatest(
            coalesce(d.start_rated_range_km, sp.rated_battery_range_km, 0) -
              coalesce(d.end_rated_range_km, ep.rated_battery_range_km, 0),
            0
          )
        end as preferred_range_diff_km
      from drives d
      left join cars c on c.id = d.car_id
      left join positions sp on sp.id = d.start_position_id
      left join positions ep on ep.id = d.end_position_id
      left join geofences sg on sg.id = d.start_geofence_id
      left join geofences eg on eg.id = d.end_geofence_id
      left join addresses sa on sa.id = d.start_address_id
      left join addresses ea on ea.id = d.end_address_id
      where d.car_id = $1
      order by d.start_date desc
      limit $2
    `,
    [carId, limit]
  );
  return result.rows;
}

async function getDrive(driveId) {
  return db.one(
    `
      select
        d.*,
        sp.latitude as start_latitude,
        sp.longitude as start_longitude,
        sp.battery_level as start_battery_level,
        ep.latitude as end_latitude,
        ep.longitude as end_longitude,
        ep.battery_level as end_battery_level,
        sg.name as start_geofence_name,
        eg.name as end_geofence_name,
        c.efficiency as car_efficiency,
        coalesce(
          sg.name,
          concat_ws(', ', coalesce(sa.name, nullif(concat_ws(' ', sa.road, sa.house_number), '')), sa.city),
          'Start'
        ) as start_address,
        coalesce(
          eg.name,
          concat_ws(', ', coalesce(ea.name, nullif(concat_ws(' ', ea.road, ea.house_number), '')), ea.city),
          'End'
        ) as end_address,
        greatest(
          coalesce(d.start_rated_range_km, sp.rated_battery_range_km, 0) -
            coalesce(d.end_rated_range_km, ep.rated_battery_range_km, 0),
          0
        ) as rated_range_diff_km,
        greatest(
          coalesce(d.start_ideal_range_km, sp.ideal_battery_range_km, 0) -
            coalesce(d.end_ideal_range_km, ep.ideal_battery_range_km, 0),
          0
        ) as ideal_range_diff_km,
        case
          when coalesce((select preferred_range from settings limit 1), 'rated') = 'ideal'
            then greatest(
              coalesce(d.start_ideal_range_km, sp.ideal_battery_range_km, 0) -
                coalesce(d.end_ideal_range_km, ep.ideal_battery_range_km, 0),
              0
            )
          else greatest(
            coalesce(d.start_rated_range_km, sp.rated_battery_range_km, 0) -
              coalesce(d.end_rated_range_km, ep.rated_battery_range_km, 0),
            0
          )
        end as preferred_range_diff_km
      from drives d
      left join cars c on c.id = d.car_id
      left join positions sp on sp.id = d.start_position_id
      left join positions ep on ep.id = d.end_position_id
      left join geofences sg on sg.id = d.start_geofence_id
      left join geofences eg on eg.id = d.end_geofence_id
      left join addresses sa on sa.id = d.start_address_id
      left join addresses ea on ea.id = d.end_address_id
      where d.id = $1
    `,
    [driveId]
  );
}

async function getDriveTrackingRows(driveId) {
  const result = await db.query(
    `
      select date, latitude, longitude, speed, elevation, battery_level
      from positions
      where drive_id = $1
        and latitude is not null
        and longitude is not null
      order by date asc
      limit 2000
    `,
    [driveId]
  );
  return downsample(result.rows, 240);
}

async function getMonthlyStats(carId) {
  const driveStats = await db.one(
    `
      with drive_data as (
        select
          d.distance,
          case
            when c.efficiency > 5 then c.efficiency / 1000.0
            else c.efficiency
          end as car_efficiency,
          case
            when coalesce((select preferred_range from settings limit 1), 'rated') = 'ideal'
              then greatest(
                coalesce(d.start_ideal_range_km, sp.ideal_battery_range_km, 0) -
                  coalesce(d.end_ideal_range_km, ep.ideal_battery_range_km, 0),
                0
              )
            else greatest(
              coalesce(d.start_rated_range_km, sp.rated_battery_range_km, 0) -
                coalesce(d.end_rated_range_km, ep.rated_battery_range_km, 0),
              0
            )
          end as range_diff_km
        from drives d
        left join cars c on c.id = d.car_id
        left join positions sp on sp.id = d.start_position_id
        left join positions ep on ep.id = d.end_position_id
        where d.car_id = $1
          and d.start_date >= date_trunc('month', now())
          and d.end_date is not null
      )
      select
        coalesce(sum(distance), 0) as distance_km,
        count(*)::int as drive_count,
        coalesce(sum(range_diff_km * car_efficiency), 0) as energy_kwh
      from drive_data
    `,
    [carId]
  );
  const chargeStats = await db.one(
    `
      with sessions as (
        select
          cp.id,
          cp.cost,
          coalesce(
            cp.charge_energy_added,
            max(c.charge_energy_added),
            cp.charge_energy_used,
            0
          ) as charge_energy_added
        from charging_processes cp
        left join charges c on c.charging_process_id = cp.id
        where cp.car_id = $1
          and cp.start_date >= date_trunc('month', now())
        group by cp.id, cp.cost, cp.charge_energy_added, cp.charge_energy_used
      )
      select
        count(*)::int as charge_count,
        coalesce(sum(cost), 0) as charging_cost,
        coalesce(sum(charge_energy_added), 0) as charge_energy_kwh
      from sessions
    `,
    [carId]
  );
  const stateStats = await getMonthlyStateHours(carId);

  const distanceKm = Number(driveStats?.distance_km || 0);
  const energyKwh = Number(driveStats?.energy_kwh || 0);
  const chargeEnergyKwh = Number(chargeStats?.charge_energy_kwh || 0);

  return {
    distanceKm,
    driveCount: Number(driveStats?.drive_count || 0),
    energyKwh,
    chargeEnergyKwh,
    efficiencyWhPerKm: distanceKm > 0 ? Math.round((energyKwh * 1000) / distanceKm) : 0,
    chargeCount: Number(chargeStats?.charge_count || 0),
    chargingCost: Number(chargeStats?.charging_cost || 0),
    onlineHours: stateStats.onlineHours,
    asleepHours: stateStats.asleepHours,
  };
}

async function getRecentCharges(carId, limit) {
  try {
    const result = await db.query(
      `
      select
        cp.*,
        gf.name as geofence_name,
        coalesce(cp.start_battery_level, first_charge.battery_level) as start_battery_level,
        coalesce(cp.end_battery_level, last_charge.battery_level) as end_battery_level,
        coalesce(cp.charge_energy_added, summary.charge_energy_added, cp.charge_energy_used) as charge_energy_added,
        summary.max_power_kw,
        summary.voltage,
        summary.current_a,
        greatest(
          coalesce(cp.end_rated_range_km, last_charge.rated_battery_range_km, 0) -
            coalesce(cp.start_rated_range_km, first_charge.rated_battery_range_km, 0),
          0
        ) as rated_range_added,
        greatest(
          coalesce(cp.end_ideal_range_km, last_charge.ideal_battery_range_km, 0) -
            coalesce(cp.start_ideal_range_km, first_charge.ideal_battery_range_km, 0),
          0
        ) as ideal_range_added
      from charging_processes cp
      left join geofences gf on gf.id = cp.geofence_id
      left join lateral (
        select battery_level, rated_battery_range_km, ideal_battery_range_km
        from charges
        where charging_process_id = cp.id
          and battery_level is not null
        order by date asc
        limit 1
      ) first_charge on true
      left join lateral (
        select battery_level, rated_battery_range_km, ideal_battery_range_km
        from charges
        where charging_process_id = cp.id
          and battery_level is not null
        order by date desc
        limit 1
      ) last_charge on true
      left join lateral (
        select
          max(charge_energy_added) as charge_energy_added,
          max(charger_power) as max_power_kw,
          avg(nullif(charger_voltage, 0)) filter (where charger_voltage > 10) as voltage,
          avg(nullif(charger_actual_current, 0)) filter (where charger_actual_current > 0) as current_a
        from charges
        where charging_process_id = cp.id
      ) summary on true
      where cp.car_id = $1
      order by cp.start_date desc
      limit $2
    `,
      [carId, limit]
    );
    return result.rows;
  } catch (_error) {
    const result = await db.query(
      `
        select
          cp.*,
          gf.name as geofence_name,
          coalesce(cp.start_battery_level, first_charge.battery_level) as start_battery_level,
          coalesce(cp.end_battery_level, last_charge.battery_level) as end_battery_level,
          coalesce(cp.charge_energy_added, summary.charge_energy_added, cp.charge_energy_used) as charge_energy_added,
          summary.max_power_kw,
          summary.voltage,
          summary.current_a
        from charging_processes cp
        left join geofences gf on gf.id = cp.geofence_id
        left join lateral (
          select battery_level
          from charges
          where charging_process_id = cp.id
            and battery_level is not null
          order by date asc
          limit 1
        ) first_charge on true
        left join lateral (
          select battery_level
          from charges
          where charging_process_id = cp.id
            and battery_level is not null
          order by date desc
          limit 1
        ) last_charge on true
        left join lateral (
          select
            max(charge_energy_added) as charge_energy_added,
            max(charger_power) as max_power_kw,
            avg(nullif(charger_voltage, 0)) filter (where charger_voltage > 10) as voltage,
            avg(nullif(charger_actual_current, 0)) filter (where charger_actual_current > 0) as current_a
          from charges
          where charging_process_id = cp.id
        ) summary on true
        where cp.car_id = $1
        order by cp.start_date desc
        limit $2
      `,
      [carId, limit]
    );
    return result.rows;
  }
}

async function getCharge(chargeId) {
  try {
    return await db.one(
      `
      select
        cp.*,
        gf.name as geofence_name,
        coalesce(cp.start_battery_level, first_charge.battery_level) as start_battery_level,
        coalesce(cp.end_battery_level, last_charge.battery_level) as end_battery_level,
        coalesce(cp.charge_energy_added, summary.charge_energy_added, cp.charge_energy_used) as charge_energy_added,
        summary.max_power_kw,
        summary.voltage,
        summary.current_a,
        greatest(
          coalesce(cp.end_rated_range_km, last_charge.rated_battery_range_km, 0) -
            coalesce(cp.start_rated_range_km, first_charge.rated_battery_range_km, 0),
          0
        ) as rated_range_added,
        greatest(
          coalesce(cp.end_ideal_range_km, last_charge.ideal_battery_range_km, 0) -
            coalesce(cp.start_ideal_range_km, first_charge.ideal_battery_range_km, 0),
          0
        ) as ideal_range_added
      from charging_processes cp
      left join geofences gf on gf.id = cp.geofence_id
      left join lateral (
        select battery_level, rated_battery_range_km, ideal_battery_range_km
        from charges
        where charging_process_id = cp.id
          and battery_level is not null
        order by date asc
        limit 1
      ) first_charge on true
      left join lateral (
        select battery_level, rated_battery_range_km, ideal_battery_range_km
        from charges
        where charging_process_id = cp.id
          and battery_level is not null
        order by date desc
        limit 1
      ) last_charge on true
      left join lateral (
        select
          max(charge_energy_added) as charge_energy_added,
          max(charger_power) as max_power_kw,
          avg(nullif(charger_voltage, 0)) filter (where charger_voltage > 10) as voltage,
          avg(nullif(charger_actual_current, 0)) filter (where charger_actual_current > 0) as current_a
        from charges
        where charging_process_id = cp.id
      ) summary on true
      where cp.id = $1
    `,
      [chargeId]
    );
  } catch (_error) {
    return db.one(
      `
        select
          cp.*,
          gf.name as geofence_name,
          coalesce(cp.start_battery_level, first_charge.battery_level) as start_battery_level,
          coalesce(cp.end_battery_level, last_charge.battery_level) as end_battery_level,
          coalesce(cp.charge_energy_added, summary.charge_energy_added, cp.charge_energy_used) as charge_energy_added,
          summary.max_power_kw,
          summary.voltage,
          summary.current_a
        from charging_processes cp
        left join geofences gf on gf.id = cp.geofence_id
        left join lateral (
          select battery_level
          from charges
          where charging_process_id = cp.id
            and battery_level is not null
          order by date asc
          limit 1
        ) first_charge on true
        left join lateral (
          select battery_level
          from charges
          where charging_process_id = cp.id
            and battery_level is not null
          order by date desc
          limit 1
        ) last_charge on true
        left join lateral (
          select
            max(charge_energy_added) as charge_energy_added,
            max(charger_power) as max_power_kw,
            avg(nullif(charger_voltage, 0)) filter (where charger_voltage > 10) as voltage,
            avg(nullif(charger_actual_current, 0)) filter (where charger_actual_current > 0) as current_a
          from charges
          where charging_process_id = cp.id
        ) summary on true
        where cp.id = $1
      `,
      [chargeId]
    );
  }
}

async function getChargeSamples(chargeId) {
  const result = await db.query(
    `
      select date, battery_level, charger_power, charger_voltage, charger_actual_current
      from charges
      where charging_process_id = $1
      order by date asc
      limit 2000
    `,
    [chargeId]
  );
  return downsample(result.rows, 240);
}

async function getMonthlyStateHours(carId) {
  const rows = await safeRows(
    `
      with clipped as (
        select
          lower(state::text) as state,
          greatest(start_date, date_trunc('month', now())) as started_at,
          least(coalesce(end_date, now()), now()) as ended_at
        from states
        where car_id = $1
          and coalesce(end_date, now()) >= date_trunc('month', now())
      )
      select
        state,
        coalesce(
          sum(extract(epoch from (ended_at - started_at))) / 3600.0,
          0
        ) as hours
      from clipped
      where ended_at > started_at
      group by state
    `,
    [carId]
  );

  return {
    onlineHours: sum(rows.filter((row) => row.state === 'online'), 'hours'),
    asleepHours: sum(rows.filter((row) => row.state === 'asleep'), 'hours'),
  };
}

async function getStateTimeline(carId) {
  const rows = await safeRows(
    `
      with clipped as (
        select
          lower(state::text) as state,
          greatest(start_date, now() - interval '30 days') as started_at,
          least(coalesce(end_date, now()), now()) as ended_at
        from states
        where car_id = $1
          and coalesce(end_date, now()) >= now() - interval '30 days'
      )
      select
        state,
        coalesce(sum(extract(epoch from (ended_at - started_at))) / 3600.0, 0) as hours
      from clipped
      where ended_at > started_at
      group by state
      order by hours desc
    `,
    [carId]
  );

  return rows
    .map((row) => ({
      label: stateLabel(row.state),
      hours: Number(row.hours || 0),
    }))
    .filter((item) => item.hours > 0);
}

async function getMonthlyMileage(carId) {
  const rows = await safeRows(
    `
      select
        to_char(date_trunc('month', start_date), 'Mon') as label,
        coalesce(sum(distance), 0) as value
      from drives
      where car_id = $1
        and start_date >= date_trunc('month', now()) - interval '5 months'
        and end_date is not null
      group by date_trunc('month', start_date)
      order by date_trunc('month', start_date)
    `,
    [carId]
  );

  return rows.map((row) => ({
    label: String(row.label || ''),
    value: Number(row.value || 0),
  }));
}

async function getRangeDegradation(carId) {
  const rows = await safeRows(
    `
      select
        to_char(date_trunc('month', c.date), 'Mon') as label,
        avg(c.rated_battery_range_km * 100.0 / nullif(c.battery_level, 0)) as value
      from charges c
      join charging_processes cp on cp.id = c.charging_process_id
      where cp.car_id = $1
        and c.date >= date_trunc('month', now()) - interval '11 months'
        and c.battery_level >= 50
        and c.rated_battery_range_km > 0
      group by date_trunc('month', c.date)
      order by date_trunc('month', c.date)
    `,
    [carId]
  );

  return rows.map((row) => ({
    label: String(row.label || ''),
    value: Number(row.value || 0),
  }));
}

async function getChargingCurves(carId) {
  const rows = await safeRows(
    `
      select
        battery_level,
        avg(charger_power) as power_kw
      from charges c
      join charging_processes cp on cp.id = c.charging_process_id
      where cp.car_id = $1
        and c.battery_level is not null
        and c.charger_power > 0
        and cp.start_date >= now() - interval '12 months'
      group by battery_level
      order by battery_level
    `,
    [carId]
  );

  const points = rows.map((row) => ({
    label: `${Math.round(Number(row.battery_level || 0))}%`,
    value: Number(row.power_kw || 0),
  }));

  return points.length >= 2
    ? [
        {
          label: 'Average charging power',
          colorHex: 0xffb35c00,
          points,
        },
      ]
    : [];
}

async function getSpeedRates(carId) {
  const rows = await safeRows(
    `
      with samples as (
        select
          floor(speed / 10.0) * 10 as speed_bucket,
          speed,
          power,
          date,
          lead(date) over (partition by drive_id order by date) as next_date
        from positions
        where car_id = $1
          and drive_id is not null
          and date >= now() - interval '12 months'
          and speed >= 10
          and power is not null
      )
      select
        speed_bucket::int as speed_kmh,
        avg(greatest(power, 0) * 1000.0 / nullif(speed, 0)) as net_wh_per_km,
        avg(abs(power) * 1000.0 / nullif(speed, 0)) as gross_wh_per_km,
        coalesce(sum(speed * extract(epoch from (coalesce(next_date, date) - date)) / 3600.0), 0) as distance_km
      from samples
      where speed_bucket between 10 and 140
      group by speed_bucket
      having count(*) >= 3
      order by speed_bucket
    `,
    [carId]
  );

  return rows.map((row) => ({
    speedKmh: Number(row.speed_kmh || 0),
    netWhPerKm: Math.round(Number(row.net_wh_per_km || 0)),
    grossWhPerKm: Math.round(Number(row.gross_wh_per_km || 0)),
    distanceKm: Number(row.distance_km || 0),
  }));
}

async function getSpeedTemperature(carId) {
  const rows = await safeRows(
    `
      select
        (floor(speed / 20.0) * 20)::int as speed_kmh,
        (round(outside_temp / 5.0) * 5)::int as temperature_c,
        avg(greatest(power, 0) * 1000.0 / nullif(speed, 0)) as wh_per_km
      from positions
      where car_id = $1
        and drive_id is not null
        and date >= now() - interval '12 months'
        and speed >= 10
        and power is not null
        and outside_temp is not null
      group by speed_kmh, temperature_c
      having count(*) >= 3
      order by temperature_c, speed_kmh
    `,
    [carId]
  );

  return rows.map((row) => ({
    speedKmh: Number(row.speed_kmh || 0),
    temperatureC: Number(row.temperature_c || 0),
    whPerKm: Math.round(Number(row.wh_per_km || 0)),
  }));
}

async function getTopStations(carId) {
  const rows = await safeRows(
    `
      with sessions as (
        select
          cp.id,
          cp.cost,
          coalesce(gf.name, 'Charging') as name,
          max(c.charge_energy_added) as energy_kwh,
          max(c.charger_power) as max_power_kw
        from charging_processes cp
        left join geofences gf on gf.id = cp.geofence_id
        left join charges c on c.charging_process_id = cp.id
        where cp.car_id = $1
          and cp.start_date >= now() - interval '12 months'
        group by cp.id, cp.cost, gf.name
      )
      select
        name,
        case
          when max(max_power_kw) >= 90 or lower(name) like '%supercharger%' then 'Supercharger'
          when max(max_power_kw) >= 20 then 'DC'
          when coalesce(sum(cost), 0) = 0 then 'Free'
          else 'AC'
        end as kind,
        coalesce(sum(energy_kwh), 0) as energy_kwh,
        coalesce(sum(cost), 0) as cost,
        count(*)::int as sessions
      from sessions
      group by name
      order by energy_kwh desc
      limit 8
    `,
    [carId]
  );

  return rows.map((row) => ({
    name: String(row.name || 'Charging'),
    kind: String(row.kind || 'Charging'),
    energyKwh: Number(row.energy_kwh || 0),
    cost: Number(row.cost || 0),
    sessions: Number(row.sessions || 0),
  }));
}

async function getDataQuality(carId, latestDataAt = null) {
  const incompleteDrives = await countRows(
    'drives',
    'car_id = $1 and (end_date is null or start_position_id is null or end_position_id is null)',
    [carId]
  );
  const incompleteCharges = await countRows(
    'charging_processes',
    'car_id = $1 and end_date is null',
    [carId]
  );
  const missingPositions = await countRows(
    'drives',
    'car_id = $1 and (start_position_id is null or end_position_id is null)',
    [carId]
  );
  const latest = latestDataAt
    ? { latest_data_at: latestDataAt }
    : await safeOne('select max(date) as latest_data_at from positions where car_id = $1', [carId]);

  return {
    incompleteDrives,
    incompleteCharges,
    missingPositions,
    lastHealthyAt: latest?.latest_data_at
      ? new Date(latest.latest_data_at).toISOString()
      : new Date(0).toISOString(),
  };
}

async function getDatabaseInfo() {
  const info = await db.one(`
    select
      current_database() as database_name,
      pg_database_size(current_database()) / 1024.0 / 1024.0 as database_size_mb
  `);
  const schema = await safeOne('select max(version) as version from schema_migrations');
  const range = await safeOne('select min(date) as first_data_at, max(date) as latest_data_at from positions');

  return {
    connected: true,
    databaseName: info?.database_name || 'teslamate',
    schemaVersion: schema?.version ? String(schema.version) : 'unknown',
    databaseSizeMb: Number(info?.database_size_mb || 0),
    carRows: await countRows('cars'),
    driveRows: await countRows('drives'),
    positionRows: await countRows('positions'),
    chargeRows: await countRows('charges'),
    chargingProcessRows: await countRows('charging_processes'),
    stateRows: await countRows('states'),
    geofenceRows: await countRows('geofences'),
    firstDataAt: range?.first_data_at
      ? new Date(range.first_data_at).toISOString()
      : new Date(0).toISOString(),
    latestDataAt: range?.latest_data_at
      ? new Date(range.latest_data_at).toISOString()
      : new Date(0).toISOString(),
    readerApiVersion: READER_API_VERSION,
  };
}

async function getDatabaseSettings() {
  const row = await safeOne(`
    select *
    from settings
    order by id
    limit 1
  `);

  return {
    available: Boolean(row),
    settings: row || {},
  };
}

async function safeOne(sql, params = []) {
  try {
    return await db.one(sql, params);
  } catch (_error) {
    return null;
  }
}

async function safeRows(sql, params = []) {
  try {
    const result = await db.query(sql, params);
    return result.rows;
  } catch (_error) {
    return [];
  }
}

async function countRows(table, where = '', params = []) {
  try {
    const safeTables = new Set([
      'cars',
      'drives',
      'positions',
      'charges',
      'charging_processes',
      'states',
      'geofences',
    ]);
    if (!safeTables.has(table)) {
      return 0;
    }

    const result = await db.one(
      `select count(*)::int as count from ${table}${where ? ` where ${where}` : ''}`,
      params
    );
    return Number(result?.count || 0);
  } catch (_error) {
    return 0;
  }
}

async function getVehicleTableDefinitions() {
  const schema = await getPublicSchemaMap();
  const definitions = new Map();

  if (schema.has('cars')) {
    const columns = schema.get('cars');
    definitions.set('cars', {
      name: 'cars',
      relation: 'selected car row',
      columns: [...columns].sort(),
      dateColumn: firstExisting(columns, ['inserted_at', 'updated_at']),
      orderColumn: defaultOrderColumn(columns),
      fromSql: `from ${quoteIdent('cars')} t`,
      whereSql: `t.${quoteIdent('id')} = $1`,
    });
  }

  for (const [table, columns] of schema.entries()) {
    if (table === 'cars' || !columns.has('car_id')) {
      continue;
    }

    definitions.set(table, {
      name: table,
      relation: 'direct car_id',
      columns: [...columns].sort(),
      dateColumn: firstDateColumn(columns),
      orderColumn: defaultOrderColumn(columns),
      fromSql: `from ${quoteIdent(table)} t`,
      whereSql: `t.${quoteIdent('car_id')} = $1`,
    });
  }

  addChargesDefinition(definitions, schema);
  addReferencedAddressDefinition(definitions, schema);
  addReferencedGeofenceDefinition(definitions, schema);

  return [...definitions.values()].sort((a, b) => {
    const priority = ['cars', 'positions', 'drives', 'charging_processes', 'charges', 'states'];
    const aPriority = priority.indexOf(a.name);
    const bPriority = priority.indexOf(b.name);
    if (aPriority !== -1 || bPriority !== -1) {
      return (aPriority === -1 ? 99 : aPriority) - (bPriority === -1 ? 99 : bPriority);
    }
    return a.name.localeCompare(b.name);
  });
}

function addChargesDefinition(definitions, schema) {
  if (definitions.has('charges') || !schema.has('charges') || !schema.has('charging_processes')) {
    return;
  }

  const charges = schema.get('charges');
  const chargingProcesses = schema.get('charging_processes');
  if (!charges.has('charging_process_id') || !chargingProcesses.has('id') || !chargingProcesses.has('car_id')) {
    return;
  }

  definitions.set('charges', {
    name: 'charges',
    relation: 'via charging_processes.car_id',
    columns: [...charges].sort(),
    dateColumn: firstDateColumn(charges),
    orderColumn: defaultOrderColumn(charges),
    fromSql: `from ${quoteIdent('charges')} t join ${quoteIdent('charging_processes')} cp on cp.${quoteIdent('id')} = t.${quoteIdent('charging_process_id')}`,
    whereSql: `cp.${quoteIdent('car_id')} = $1`,
  });
}

function addReferencedAddressDefinition(definitions, schema) {
  if (definitions.has('addresses') || !schema.has('addresses')) {
    return;
  }

  const references = [];
  if (schema.has('drives')) {
    const drives = schema.get('drives');
    for (const column of ['start_address_id', 'end_address_id']) {
      if (drives.has(column)) {
        references.push(
          `select ${quoteIdent(column)} as id from ${quoteIdent('drives')} where ${quoteIdent('car_id')} = $1 and ${quoteIdent(column)} is not null`
        );
      }
    }
  }
  if (schema.has('positions')) {
    const positions = schema.get('positions');
    if (positions.has('address_id')) {
      references.push(
        `select ${quoteIdent('address_id')} as id from ${quoteIdent('positions')} where ${quoteIdent('car_id')} = $1 and ${quoteIdent('address_id')} is not null`
      );
    }
  }

  if (references.length === 0) {
    return;
  }

  const columns = schema.get('addresses');
  definitions.set('addresses', {
    name: 'addresses',
    relation: 'referenced by vehicle drives or positions',
    columns: [...columns].sort(),
    dateColumn: firstDateColumn(columns),
    orderColumn: defaultOrderColumn(columns),
    fromSql: `from ${quoteIdent('addresses')} t`,
    whereSql: `t.${quoteIdent('id')} in (${references.join(' union ')})`,
  });
}

function addReferencedGeofenceDefinition(definitions, schema) {
  if (definitions.has('geofences') || !schema.has('geofences')) {
    return;
  }

  const references = [];
  if (schema.has('drives')) {
    const drives = schema.get('drives');
    for (const column of ['start_geofence_id', 'end_geofence_id']) {
      if (drives.has(column)) {
        references.push(
          `select ${quoteIdent(column)} as id from ${quoteIdent('drives')} where ${quoteIdent('car_id')} = $1 and ${quoteIdent(column)} is not null`
        );
      }
    }
  }
  if (schema.has('charging_processes')) {
    const chargingProcesses = schema.get('charging_processes');
    if (chargingProcesses.has('geofence_id')) {
      references.push(
        `select ${quoteIdent('geofence_id')} as id from ${quoteIdent('charging_processes')} where ${quoteIdent('car_id')} = $1 and ${quoteIdent('geofence_id')} is not null`
      );
    }
  }
  if (schema.has('positions')) {
    const positions = schema.get('positions');
    if (positions.has('geofence_id')) {
      references.push(
        `select ${quoteIdent('geofence_id')} as id from ${quoteIdent('positions')} where ${quoteIdent('car_id')} = $1 and ${quoteIdent('geofence_id')} is not null`
      );
    }
  }

  if (references.length === 0) {
    return;
  }

  const columns = schema.get('geofences');
  definitions.set('geofences', {
    name: 'geofences',
    relation: 'referenced by vehicle drives, charges, or positions',
    columns: [...columns].sort(),
    dateColumn: firstDateColumn(columns),
    orderColumn: defaultOrderColumn(columns),
    fromSql: `from ${quoteIdent('geofences')} t`,
    whereSql: `t.${quoteIdent('id')} in (${references.join(' union ')})`,
  });
}

async function getVehicleTableMeta(definition, carId) {
  const rowCount = await countVehicleTableRows(definition, carId);
  const dateRange = await getVehicleTableDateRange(definition, carId);

  return {
    name: definition.name,
    relation: definition.relation,
    route: `/api/cars/${carId}/database/tables/${definition.name}`,
    columns: definition.columns,
    columnCount: definition.columns.length,
    rowCount,
    dateColumn: definition.dateColumn,
    orderColumn: definition.orderColumn,
    firstDataAt: dateRange.firstDataAt,
    latestDataAt: dateRange.latestDataAt,
  };
}

async function getVehicleTablePage(definition, carId, query) {
  const limit = boundedInt(query.limit, DEFAULT_RAW_LIMIT, MAX_RAW_LIMIT);
  const offset = boundedInt(query.offset, 0, Number.MAX_SAFE_INTEGER);
  const order = String(query.order || 'desc').toLowerCase() === 'asc' ? 'asc' : 'desc';
  const params = [carId];
  const where = [definition.whereSql];

  if (definition.dateColumn && query.from) {
    params.push(new Date(String(query.from)).toISOString());
    where.push(`t.${quoteIdent(definition.dateColumn)} >= $${params.length}`);
  }
  if (definition.dateColumn && query.to) {
    params.push(new Date(String(query.to)).toISOString());
    where.push(`t.${quoteIdent(definition.dateColumn)} <= $${params.length}`);
  }

  const orderColumn = definition.orderColumn || definition.dateColumn || 'id';
  params.push(limit);
  const limitIndex = params.length;
  params.push(offset);
  const offsetIndex = params.length;

  const result = await db.query(
    `
      select t.*
      ${definition.fromSql}
      where ${where.join(' and ')}
      order by t.${quoteIdent(orderColumn)} ${order}
      limit $${limitIndex}
      offset $${offsetIndex}
    `,
    params
  );

  const totalRows = await countVehicleTableRows(definition, carId, where.slice(1), params.slice(1, -2));

  return {
    table: definition.name,
    relation: definition.relation,
    columns: definition.columns,
    limit,
    offset,
    order,
    dateColumn: definition.dateColumn,
    totalRows,
    returnedRows: result.rows.length,
    rows: result.rows,
  };
}

async function countVehicleTableRows(definition, carId, extraWhere = [], extraParams = []) {
  const params = [carId, ...extraParams];
  const result = await db.one(
    `
      select count(*)::int as count
      ${definition.fromSql}
      where ${[definition.whereSql, ...extraWhere].join(' and ')}
    `,
    params
  );
  return Number(result?.count || 0);
}

async function getVehicleTableDateRange(definition, carId) {
  if (!definition.dateColumn) {
    return {
      firstDataAt: null,
      latestDataAt: null,
    };
  }

  const result = await safeOne(
    `
      select
        min(t.${quoteIdent(definition.dateColumn)}) as first_data_at,
        max(t.${quoteIdent(definition.dateColumn)}) as latest_data_at
      ${definition.fromSql}
      where ${definition.whereSql}
    `,
    [carId]
  );

  return {
    firstDataAt: result?.first_data_at ? new Date(result.first_data_at).toISOString() : null,
    latestDataAt: result?.latest_data_at ? new Date(result.latest_data_at).toISOString() : null,
  };
}

async function getPublicSchemaMap() {
  const rows = await safeRows(`
    select table_name, column_name
    from information_schema.columns
    where table_schema = 'public'
    order by table_name, ordinal_position
  `);
  const schema = new Map();
  for (const row of rows) {
    if (!schema.has(row.table_name)) {
      schema.set(row.table_name, new Set());
    }
    schema.get(row.table_name).add(row.column_name);
  }
  return schema;
}

function firstDateColumn(columns) {
  return firstExisting(columns, [
    'date',
    'start_date',
    'end_date',
    'start_time',
    'end_time',
    'inserted_at',
    'updated_at',
  ]);
}

function defaultOrderColumn(columns) {
  return (
    firstExisting(columns, ['date', 'start_date', 'start_time', 'inserted_at', 'updated_at', 'id']) ||
    [...columns][0]
  );
}

function firstExisting(columns, candidates) {
  return candidates.find((column) => columns.has(column)) || null;
}

function boundedInt(value, fallback, max) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.max(0, Math.min(parsed, max));
}

function quoteIdent(identifier) {
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(identifier)) {
    throw new Error(`Unsafe SQL identifier: ${identifier}`);
  }
  return `"${identifier}"`;
}

function mapVehicle(car, position) {
  return {
    displayName: car?.name || `Car ${car?.id || ''}`.trim() || 'Tesla',
    model: car?.model || 'Tesla',
    state: position?.battery_level ? 'online' : 'offline',
    batteryLevel: Math.round(numberFrom(position, ['battery_level'])),
    usableBatteryLevel: Math.round(numberFrom(position, ['usable_battery_level'])),
    ratedRangeKm: numberFrom(position, ['rated_battery_range_km']),
    idealRangeKm: numberFrom(position, ['ideal_battery_range_km']),
    odometerKm: numberFrom(position, ['odometer']),
    locationName: 'Current location',
    latitude: numberFrom(position, ['latitude']),
    longitude: numberFrom(position, ['longitude']),
    lastSeen: position?.date
      ? new Date(position.date).toISOString()
      : new Date(0).toISOString(),
    outsideTempC: numberFrom(position, ['outside_temp']),
    insideTempC: numberFrom(position, ['inside_temp']),
    powerKw: numberFrom(position, ['power']),
    pluggedIn: false,
  };
}

function buildMonthlyStats(drives, charges) {
  const now = new Date();
  const thisMonth = (iso) => {
    const date = new Date(iso);
    return date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth();
  };
  const monthlyDrives = drives.filter((drive) => thisMonth(drive.startedAt));
  const monthlyCharges = charges.filter((charge) => thisMonth(charge.startedAt));
  const distanceKm = sum(monthlyDrives, 'distanceKm');
  const energyKwh = sum(monthlyDrives, 'energyKwh');

  return {
    distanceKm,
    driveCount: monthlyDrives.length,
    energyKwh,
    chargeEnergyKwh: sum(monthlyCharges, 'addedKwh'),
    efficiencyWhPerKm: distanceKm > 0 ? Math.round((energyKwh * 1000) / distanceKm) : 0,
    chargeCount: monthlyCharges.length,
    chargingCost: sum(monthlyCharges, 'cost'),
    onlineHours: 0,
    asleepHours: 0,
  };
}

function buildLocations(_car, position, charges) {
  const currentLocation = position?.latitude
    ? [
        {
          name: 'Current location',
          address: `${position.latitude}, ${position.longitude}`,
          kind: 'Current',
          visitCount: 1,
          lastVisitedAt: new Date(position.date).toISOString(),
          distanceFromHomeKm: 0,
        },
      ]
    : [];

  const chargingLocations = charges.slice(0, 5).map((charge) => ({
    name: charge.location,
    address: charge.location,
    kind: 'Charging',
    visitCount: 1,
    lastVisitedAt: charge.startedAt,
    distanceFromHomeKm: 0,
  }));

  return [...currentLocation, ...chargingLocations];
}

function buildAnalytics(monthlyStats, drives, charges, database, extra = {}) {
  const chargingCosts = buildChargingCosts(monthlyStats, charges);
  const batteryStats = buildBatteryStats(
    extra.rangeDegradation || [],
    extra.car,
    extra.position
  );

  return {
    currentDrive: {
      isDriving: false,
      elapsedMinutes: 0,
      distanceKm: 0,
      averageSpeedKmh: 0,
      efficiencyWhPerKm: 0,
      energyKwh: 0,
      elevationGainM: 0,
      currentRangeKm: 0,
      odometerKm: 0,
    },
    currentCharge: {
      isCharging: false,
      addedKwh: 0,
      addedRangeKm: 0,
      powerKw: 0,
      voltage: 0,
      currentA: 0,
      minutesRemaining: 0,
      odometerKm: 0,
    },
    chargingCosts,
    batteryStats,
    dataQuality: extra.dataQuality || {
      incompleteDrives: 0,
      incompleteCharges: 0,
      missingPositions: 0,
      lastHealthyAt: database.latestDataAt,
    },
    amortization: {
      purchasePrice: 0,
      currentValue: 0,
      savingsToDate: 0,
      breakEvenPercent: 0,
      estimatedBreakEvenDate: new Date(0).toISOString(),
    },
    stateTimeline: extra.stateTimeline || [],
    monthlyMileage: extra.monthlyMileage || drives.slice(0, 8).reverse().map((drive) => ({
      label: drive.startedAt.slice(5, 10),
      value: drive.distanceKm,
    })),
    rangeDegradation: extra.rangeDegradation || [],
    chargingCurves: extra.chargingCurves || [],
    speedRates: extra.speedRates || [],
    speedTemperature: extra.speedTemperature || [],
    topStations: extra.topStations || charges.slice(0, 5).map((charge) => ({
      name: charge.location,
      kind: stationKind(charge),
      energyKwh: charge.addedKwh,
      cost: charge.cost,
      sessions: 1,
    })),
  };
}

function buildChargingCosts(monthlyStats, charges) {
  const now = new Date();
  const monthlyCharges = charges.filter((charge) => {
    const startedAt = new Date(charge.startedAt);
    return (
      !Number.isNaN(startedAt.getTime()) &&
      startedAt.getUTCFullYear() === now.getUTCFullYear() &&
      startedAt.getUTCMonth() === now.getUTCMonth()
    );
  });
  const split = {
    freeEnergyKwh: 0,
    acEnergyKwh: 0,
    dcEnergyKwh: 0,
    superchargerEnergyKwh: 0,
    acCost: 0,
    dcCost: 0,
    superchargerCost: 0,
  };

  for (const charge of monthlyCharges) {
    const energy = Number(charge.addedKwh || 0);
    const cost = Number(charge.cost || 0);
    const kind = stationKind(charge);
    if (cost <= 0) {
      split.freeEnergyKwh += energy;
    }
    if (kind === 'Supercharger') {
      split.superchargerEnergyKwh += energy;
      split.superchargerCost += cost;
    } else if (kind === 'DC') {
      split.dcEnergyKwh += energy;
      split.dcCost += cost;
    } else {
      split.acEnergyKwh += energy;
      split.acCost += cost;
    }
  }

  const totalEnergyUsedKwh =
    Number(monthlyStats.chargeEnergyKwh || 0) || sum(monthlyCharges, 'addedKwh');
  const totalCost = Number(monthlyStats.chargingCost || 0);
  const distanceKm = Number(monthlyStats.distanceKm || 0);
  const driveEnergyKwh = Number(monthlyStats.energyKwh || 0);
  const grossEnergyKwh = Math.max(totalEnergyUsedKwh, driveEnergyKwh);

  return {
    ...split,
    totalEnergyUsedKwh,
    totalCost,
    costPer100Km: distanceKm > 0 ? (totalCost / distanceKm) * 100 : 0,
    costPerKwh: totalEnergyUsedKwh > 0 ? totalCost / totalEnergyUsedKwh : 0,
    netConsumptionWhPerKm: Number(monthlyStats.efficiencyWhPerKm || 0),
    grossConsumptionWhPerKm:
      distanceKm > 0 && grossEnergyKwh > 0
        ? Math.round((grossEnergyKwh * 1000) / distanceKm)
        : distanceKm > 0 && driveEnergyKwh > 0
          ? Math.round((driveEnergyKwh * 1000) / distanceKm)
          : 0,
  };
}

function buildBatteryStats(rangeDegradation, car, position) {
  const values = rangeDegradation.map((point) => Number(point.value || 0)).filter((value) => value > 0);
  const latestFullRangeKm = fullRangeKmFromPosition(position);
  const observedValues = latestFullRangeKm > 0 ? [...values, latestFullRangeKm] : values;
  const ratedRangeNowKm = latestFullRangeKm || values[values.length - 1] || 0;
  const ratedRangeStartKm = values[0] || ratedRangeNowKm;
  const bestRangeKm = observedValues.length ? Math.max(...observedValues) : 0;
  const worstRangeKm = observedValues.length ? Math.min(...observedValues) : 0;
  const efficiencyKwhPerKm = efficiencyKwhPerKmFromCar(car);
  const estimatedCapacityKwh =
    efficiencyKwhPerKm > 0 && ratedRangeNowKm > 0 ? ratedRangeNowKm * efficiencyKwhPerKm : 0;
  const nominalFullPackKwh =
    efficiencyKwhPerKm > 0 && bestRangeKm > 0 ? bestRangeKm * efficiencyKwhPerKm : estimatedCapacityKwh;

  return {
    estimatedCapacityKwh,
    nominalFullPackKwh,
    degradationPercent:
      ratedRangeStartKm > 0 && ratedRangeNowKm > 0
        ? Math.max(0, ((ratedRangeStartKm - ratedRangeNowKm) / ratedRangeStartKm) * 100)
        : 0,
    ratedRangeNowKm,
    ratedRangeStartKm,
    bestRangeKm,
    worstRangeKm,
  };
}

function fullRangeKmFromPosition(position) {
  const batteryLevel = numberFrom(position, ['battery_level', 'usable_battery_level']);
  const ratedRangeKm = numberFrom(position, ['rated_battery_range_km']);
  if (batteryLevel <= 0 || ratedRangeKm <= 0) {
    return 0;
  }
  return (ratedRangeKm * 100) / batteryLevel;
}

function efficiencyKwhPerKmFromCar(car) {
  const efficiency = numberFrom(car, ['efficiency']);
  if (efficiency <= 0) {
    return 0;
  }
  return efficiency > 5 ? efficiency / 1000 : efficiency;
}

function stationKind(charge) {
  const location = String(charge.location || '');
  const maxPowerKw = Number(charge.maxPowerKw || 0);
  if (/supercharger/i.test(location) || maxPowerKw >= 90) {
    return 'Supercharger';
  }
  if (maxPowerKw >= 20) {
    return 'DC';
  }
  if (Number(charge.cost || 0) <= 0) {
    return 'Free';
  }
  return 'AC';
}

function stateLabel(state) {
  return (
    {
      asleep: 'Asleep',
      online: 'Online',
      driving: 'Driving',
      charging: 'Charging',
      offline: 'Offline',
    }[String(state || '').toLowerCase()] || 'Unknown'
  );
}

function mapTrackingPoint(row) {
  return {
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
    label: row.date ? new Date(row.date).toISOString() : '',
    speedKmh: numberFrom(row, ['speed']),
    elevationM: numberFrom(row, ['elevation']),
    batteryLevel: numberFrom(row, ['battery_level']),
  };
}

function downsample(items, maxItems) {
  if (items.length <= maxItems) {
    return items;
  }
  const step = items.length / maxItems;
  const sampled = [];
  for (let i = 0; i < maxItems; i += 1) {
    sampled.push(items[Math.floor(i * step)]);
  }
  return sampled;
}

function sum(items, key) {
  return items.reduce((total, item) => total + Number(item[key] || 0), 0);
}
