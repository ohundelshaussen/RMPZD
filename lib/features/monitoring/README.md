# Monitoring

The monitor inbox reads `casos_monitoreo` through select-only queries using the
authenticated user's session. It subscribes to public-schema Realtime changes,
keeps patient data in memory only, and does not use the local assessment sync
pipeline. Case changes use the `tomar_caso`, `liberar_caso`,
`registrar_evento_caso`, and `cerrar_caso` RPCs so the server validates and
records each action.

Doctors can read status/result fields only for their own visible assessment
UUIDs and refer synced evaluations through `remitir_registro`. Referral states
are kept in memory and displayed in the history and result screens.

The list fetch embeds `assessments(patient_id, nombre_paciente,
semanas_gestacion, edad_materna)`, plus the referring doctor's display name.
New and assigned cases are fetched in pages of 50. Closed cases are restricted
to the latest 50 rows where `cerrado_por` matches the signed-in monitor.

Local notifications use the `emergencias` Android channel. Their content
includes only the priority and municipality/department. Doctor referrals use
the privacy-safe text “Paciente remitida por el doctor” and the case ID remains
the notification payload used to open the case detail.
