# Dashboards Pillar Reference (Optional)

Only generate this section when the user chose "yes" for the Dashboards pillar in the setup wizard.

## Directory Structure

```
streamlit/
├── shared/
│   ├── auth.py          ← PAT-based auth helper
│   ├── theme.py         ← Branding / color theme constants
│   └── data_utils.py    ← Shared query helpers
└── apps/
    └── {APP_NAME}/
        ├── app.py       ← Main Streamlit entrypoint
        ├── environment.yml
        └── snowflake.yml
```

## streamlit/shared/auth.py

```python
"""streamlit/shared/auth.py — Snowflake session factory for Streamlit apps."""
import toml
from snowflake.snowpark import Session


def get_session(connection: str = "default") -> Session:
    """Create a Snowpark session from config.toml. Falls back to Streamlit secrets in cloud."""
    try:
        import streamlit as st
        # Streamlit Cloud: use st.secrets
        return Session.builder.configs(dict(st.secrets["snowflake"])).create()
    except (KeyError, AttributeError):
        pass

    cfg = toml.load("config.toml").get("connections", {}).get(connection, {})
    return Session.builder.configs(cfg).create()
```

## streamlit/shared/theme.py

```python
"""streamlit/shared/theme.py — Shared UI constants."""

BRAND_COLOR   = "#29B5E8"   # Snowflake blue
ACCENT_COLOR  = "#11567F"
FONT_FAMILY   = "Inter, sans-serif"

PAGE_CONFIG = dict(
    page_title  = "{PROJECT_NAME_TITLE}",
    page_icon   = "❄️",
    layout      = "wide",
    initial_sidebar_state = "expanded",
)
```

## streamlit/apps/{APP_NAME}/app.py

```python
"""streamlit/apps/{APP_NAME}/app.py — {APP_NAME} dashboard."""
import sys
sys.path.insert(0, "../../shared")

import streamlit as st
from auth import get_session
from theme import PAGE_CONFIG

st.set_page_config(**PAGE_CONFIG)

@st.cache_data(ttl=300)
def load_data():
    session = get_session()
    return session.sql(
        "SELECT * FROM {DATABASE}.{SCHEMA}.MART_{TABLE_NAME}_ENRICHED LIMIT 1000"
    ).to_pandas()


def main():
    st.title("{APP_NAME_TITLE}")
    st.caption("Source: `{DATABASE}.{SCHEMA}.MART_{TABLE_NAME}_ENRICHED`")

    with st.spinner("Loading data..."):
        df = load_data()

    st.dataframe(df, use_container_width=True)
    st.metric("Rows", len(df))


if __name__ == "__main__":
    main()
```

## streamlit/apps/{APP_NAME}/snowflake.yml

```yaml
definition_version: 1
streamlit:
  name: {APP_NAME_UPPER}
  stage: {APP_NAME_UPPER}_STAGE
  query_warehouse: {WAREHOUSE}
  main_file: app.py
  env_file: environment.yml
  title: "{APP_NAME_TITLE}"
  comment: "Streamlit dashboard for {PROJECT_NAME_TITLE}"
```

## streamlit/apps/{APP_NAME}/environment.yml

```yaml
name: {app_name_lower}_env
channels:
  - snowflake
  - conda-forge
dependencies:
  - python=3.10
  - snowflake-snowpark-python
  - streamlit
  - pandas
  - altair
```

## Deployment Note

After scaffolding, deploy the Streamlit app to Snowflake with:

```bash
snow streamlit deploy \
  --app-name {APP_NAME_UPPER} \
  --file streamlit/apps/{APP_NAME}/app.py \
  --warehouse {WAREHOUSE} \
  --connection default
```
