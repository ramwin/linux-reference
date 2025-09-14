# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'Linux Reference'
copyright = '2024, Xiang Wang'
author = 'Xiang Wang'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
        "myst_parser",
        "sphinx_design",
        "sphinx.ext.todo",
        "sphinx.ext.autodoc",
        "sphinxcontrib.mermaid",
        "sphinx.ext.mathjax",
        ]

templates_path = ['_templates']
exclude_patterns = [
        '_build',
        '.DS_Store',
        '.git',
        'Thumbs.db',
        "software/lz4/abc/directory/*.md",
        ]

language = 'zh-cn'

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']
source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}
myst_enable_extensions = [
        "amsmath",
        "attrs_inline",
        "colon_fence",
        "deflist",
        "dollarmath",
        "fieldlist",
        "strikethrough",
        "tasklist",
]
myst_heading_anchors = 7
html_css_files = [
        "custom.css"
        ]
todo_include_todos = True
latex_use_xindy = True
smartquotes = True
sphinxmermaid_mermaid_init = {
  'theme': 'base',
  'themeVariables': {
    'fontSize': '40px',
  }
}
suppress_warnings = [
    "myst.header",
    "myst.xref_missing",
    "myst.not_included",
    "toc.not_included",
]
mermaid_version = "11.9.0"
mermaid_use_local = "/_static/node_modules/mermaid/dist/mermaid.esm.min.mjs"
mermaid_elk_use_local = "/_static/node_modules/@mermaid-js/layout-elk/dist/mermaid-layout-elk.esm.min.mjs"
d3_use_local = "/_static/node_modules/d3/dist/d3.min.js"
mathjax_path = "/_static/node_modules/mathjax/unpacked/MathJax.js"
