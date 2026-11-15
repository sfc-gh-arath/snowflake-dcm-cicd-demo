# Snowflake DCM CI/CD Demo (DEV → PROD)

Declarative CI/CD for Snowflake with **DCM Projects** and **GitHub Actions** (OIDC, no stored keys).
One set of definitions, two environments, promoted through an approval gate.

## What's deployed

| Object type | DEV | PROD |
| --- | --- | --- |
| Database / schemas | `SALES_CICD_DEV` (`RAW`, `ANALYTICS`, `APPS`) | `SALES_CICD_PROD` |
| Warehouse | `SALES_CICD_WH_DEV` | `SALES_CICD_WH_PROD` |
| Table | `RAW.ORDERS` | same |
| Dynamic table | `ANALYTICS.DT_DAILY_SALES` (lag 1 hour) | lag 5 minutes |
| Stored procedure | `APPS.SP_LOAD_ORDERS(NUM_ROWS)` | same |
| Semantic view | `ANALYTICS.SV_SALES` | same |
| Notebook (Code Bundle) | `APPS.SALES_ANALYSIS` | same |

DCM project objects (account `SFSENORTHAMERICA-DEMO459`, owner role `DCM_DEVELOPER`):
`DCM_DEMO.PROJECTS.SALES_CICD_DEV` and `DCM_DEMO.PROJECTS.SALES_CICD_PROD`.

## Repo layout

```
sales_cicd/                       DCM project
├── manifest.yml                  targets DEV / PROD + templating (env, target_lag)
├── sources/definitions/
│   ├── infrastructure.sql        database, schemas, warehouse
│   ├── raw.sql                   table
│   ├── transform.sql             dynamic table + stored procedure
│   ├── serve.sql                 semantic view
│   └── jobs.sql                  code bundle (notebook)
└── code_bundles/sales_analysis/  notebook + code_bundle.yml (project asset)
tests/smoke_test.sql              post-deploy checks (all 5 object types)
.github/workflows/
├── dcm-plan.yml                  PR → analyze + plan DEV and PROD
└── dcm-deploy.yml                main → deploy DEV + test → (approval) → deploy PROD + test
```

## CI/CD security model

- Service users `DCM_CICD_DEV_SVC` / `DCM_CICD_PROD_SVC`: `TYPE = SERVICE`, OIDC workload identity,
  subject bound to the GitHub environment (`...:environment:dev` / `...:environment:prod`).
- User-level network policy `DCM_CICD_GITHUB_POLICY` uses the Snowflake-managed rule
  `SNOWFLAKE.NETWORK_SECURITY.GITHUBACTIONS_GLOBAL`. The account VPN policy is untouched.
- GitHub environment `prod` requires reviewer approval before the PROD job runs.

## Demo script

**1. Tour** (2 min) — `manifest.yml` (two targets, one codebase), definitions use `{{env}}` and
`{{target_lag}}`, no ordering logic, notebook packaged as an asset.

**2. Show DEV in Snowsight** — `SALES_CICD_DEV` objects; `DCM_DEMO.PROJECTS.SALES_CICD_DEV`
deployment history:
```sql
SHOW DEPLOYMENTS IN DCM PROJECT DCM_DEMO.PROJECTS.SALES_CICD_DEV;
SHOW ENTITIES IN DCM PROJECT DCM_DEMO.PROJECTS.SALES_CICD_DEV;
```

**3. Make a change on a branch**
```bash
git checkout -b feature/add-region
```
- `raw.sql`: add `REGION VARCHAR COMMENT 'Sales region'` at the end of `ORDERS`
- `transform.sql`: add `REGION` to the procedure insert (e.g. `ARRAY_CONSTRUCT('NA','EMEA','APAC')[UNIFORM(0,2,RANDOM())]::VARCHAR`),
  and to the dynamic table select + group by
- `serve.sql`: add dimension `orders.REGION AS orders.REGION`
- notebook: add a revenue-by-region cell

Locally preview: `cd sales_cicd && snow dcm plan --target DEV -c demo459 --role DCM_DEVELOPER`
→ the table is **ALTERed** (data kept), not recreated.

**4. Open a PR** → `DCM Plan` workflow runs analyze + plan for DEV and PROD. Review the changeset
in the job log.

**5. Merge** → `DCM Deploy`:
- `deploy-dev`: plan, deploy, smoke test (procedure, dynamic table, semantic view, notebook)
- `deploy-prod`: waits for approval → **approve in GitHub** → plan, deploy, smoke test

**6. Compare environments**
```sql
SHOW DYNAMIC TABLES IN SCHEMA SALES_CICD_PROD.ANALYTICS;   -- target_lag 5 minutes
SELECT * FROM SEMANTIC_VIEW(SALES_CICD_PROD.ANALYTICS.SV_SALES
  METRICS orders.TOTAL_REVENUE DIMENSIONS orders.ORDER_DATE);
```
Optional: ask Cortex Analyst questions against `SV_SALES`.

**7. Drift detection (optional)** — change PROD by hand, e.g.
`ALTER DYNAMIC TABLE SALES_CICD_PROD.ANALYTICS.DT_DAILY_SALES SET TARGET_LAG = '1 day';`
then re-run the deploy workflow (Actions → DCM Deploy → Run workflow): the plan shows the drift and
the deploy restores 5 minutes.

**8. Drop by removal (optional)** — delete a `DEFINE` on a branch and show the plan's `DROP` —
why the plan is reviewed before every deploy.

## Local commands

```bash
cd sales_cicd
snow dcm raw-analyze --target DEV -c demo459 --role DCM_DEVELOPER
snow dcm plan        --target DEV -c demo459 --role DCM_DEVELOPER --save-output
snow dcm deploy      --target DEV -c demo459 --role DCM_DEVELOPER --alias "my change"
cd .. && snow sql -c demo459 --role DCM_DEVELOPER -f tests/smoke_test.sql --variable env=DEV
```

## Notes

- Code Bundles, semantic views in DCM and project assets are Preview features.
- Asset files are not Jinja-rendered, so the notebook reads `--env` from `ARGUMENTS` and
  `code_bundle.yml` uses a fixed `query_warehouse` (`DCM_DEMO_1_WH_DEV`).
- The semantic view is built on `RAW.ORDERS`: a semantic view on a dynamic table can't be created
  in the same deployment as the dynamic table.

## Cleanup

```sql
-- drops all managed objects, then the project objects
EXECUTE DCM PROJECT DCM_DEMO.PROJECTS.SALES_CICD_PROD PURGE;
EXECUTE DCM PROJECT DCM_DEMO.PROJECTS.SALES_CICD_DEV PURGE;
DROP DCM PROJECT DCM_DEMO.PROJECTS.SALES_CICD_PROD;
DROP DCM PROJECT DCM_DEMO.PROJECTS.SALES_CICD_DEV;
DROP USER DCM_CICD_DEV_SVC; DROP USER DCM_CICD_PROD_SVC;
DROP NETWORK POLICY DCM_CICD_GITHUB_POLICY;
```
