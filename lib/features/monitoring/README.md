# Monitoring

The monitor inbox reads `casos_monitoreo` directly through Supabase using the
authenticated user's session and the database's RLS policies. It subscribes to
public-schema Realtime changes, keeps patient data in memory only, and does not
use the local assessment sync pipeline.

The list fetch embeds `assessments(patient_id, nombre_paciente,
semanas_gestacion, edad_materna)`. New and assigned cases are fetched in pages
of 50. Closed cases are restricted to the latest 50 rows where `cerrado_por`
matches the signed-in monitor.

Local notifications use the `emergencias` Android channel. Their content
includes only the priority and municipality/department; the case ID is the
notification payload used to open the placeholder detail page. Case details
and management actions are intentionally deferred to the next task.
