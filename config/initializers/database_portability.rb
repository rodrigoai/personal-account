# Supabase exposes several platform-owned schemas. Ledgerly owns only `public`,
# so schema dumps must remain loadable in a plain PostgreSQL database and in CI.
ActiveRecord.dump_schemas = "public"
