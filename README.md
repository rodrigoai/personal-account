# Ledgerly

Ledgerly is a local-first Rails and Hotwire workspace for importing Santander statements, categorizing movements, and reviewing monthly finances.

## Supported statements

- Santander current-account statements exported as CSV, XLS, or XLSX.
- Santander credit-card statements exported as PDF.

The parsers validate the Santander layout before importing. Credit-card PDFs retain their detailed rows even when reconciliation fails; a mismatch is shown for review instead of being replaced by a synthetic total.

LibreOffice (`soffice`) converts XLS/XLSX files and Poppler (`pdftotext`) preserves the multi-column PDF layout. Set `LIBREOFFICE_BIN` and `PDFTOTEXT_BIN` when those executables are not on `PATH`.

## Architecture

- Ruby 4.0.6+ and Rails 7.2
- PostgreSQL, currently hosted by Supabase
- Hotwire and Tailwind CSS
- Active Storage for statement files
- Solid Queue for durable imports

Ingestion is locked, transactional, retryable, and idempotent per import. Exact descriptions reuse the latest manual category locally; remaining rows are classified in one structured OpenAI Responses API call. Rows the model cannot classify reliably are assigned to the reserved **Not identified** category and remain in the review queue.

The shared workspace period filters the overview, transactions, reports, and import history by **statement month**. It defaults to the current month; select **All months** to remove the restriction. The chosen period persists across pages in the browser session. The overview chart shows the 12 months ending in the selected month (or the current month when showing all data). Categories and individual statement details remain available regardless of the period.

Transaction search matches descriptions, account names, category names, and notes, ignoring case. Search text persists when navigating away and back, combines with the month and review filters, and can be reset with **Clear search**.

The **Categories** picker on Transactions accepts multiple selections. Selecting a parent includes that category and every level of its subcategories; selecting several categories shows entries matching any of them. Click **Apply filters** or **Search** to apply the selection together with the existing month, search, and review filters. Category selections persist across navigation and month changes. **Clear categories** (or applying with every checkbox unchecked) removes only the category restriction; **Clear search** removes only the search text.

Changing a category in Transactions also updates all existing entries with the exact same description and income/expense direction across every month of that statement year, including other accounts. Other years and descriptions are left unchanged. Matching entries are marked categorized with full confidence; notes remain specific to each entry. Saving notes without changing the category does not update other entries.

## Setup

```bash
cp .env.example .env
# Add OPENAI_API_KEY to enable transaction classification during ingestion.
# Development uses local PostgreSQL by default. Set DEVELOPMENT_DATABASE_URL
# only when your local database uses a different host, port, or name.
# DATABASE_URL is reserved for production.
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/dev
```

Open `http://localhost:3000`. `bin/dev` starts Rails, Tailwind, and the Solid Queue worker. Uploaded files are limited to 10 MB and must match both an allowed extension and a detected document MIME type.

## Verification

```bash
bin/rails test
bin/rails zeitwerk:check
bundle exec rake assets:precompile
```

Tests use `TEST_DATABASE_URL`, defaulting to `postgresql://127.0.0.1/personal_account_test`. Sanitized fixtures under `test/fixtures/files` make the suite independent of private statements and external document binaries. Real statements in `data/` are intentionally ignored by Git and can be used for local compatibility smoke tests.

## Production publication blocker

Ledgerly is intentionally a single-user local application today. Do not expose it publicly until authentication, session management, authorization, and per-user ownership have been implemented and reviewed. Production already requires a real Rails secret, enables SSL by default, uses durable jobs, and expects an explicit Active Storage service, but those controls do not replace authentication.

For publication, configure the AWS-compatible Active Storage settings in `.env.example`, run `bin/rails db:prepare`, run `bin/jobs` as a persistent worker, and put authentication ahead of all other launch work.

## Database portability

Ledgerly owns only PostgreSQL's `public` schema. Schema dumps exclude Supabase-owned schemas and extensions, so a clean database or CI environment can load the application schema without requiring the Supabase platform extensions.
