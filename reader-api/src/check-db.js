const db = require('./db');
const { getSchemaDiagnostics } = require('./diagnostics');

async function main() {
  const diagnostics = await getSchemaDiagnostics();
  console.log(JSON.stringify(diagnostics, null, 2));
  await db.pool.end();

  if (diagnostics.status !== 'ready') {
    process.exitCode = 2;
  }
}

main().catch(async (error) => {
  console.error(error);
  await db.pool.end();
  process.exitCode = 1;
});
