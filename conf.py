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
        "sphinxmermaid",
        # "sphinxcontrib.mermaid",
        ]

templates_path = ['_templates']
exclude_patterns = [
        '_build',
        '.DS_Store',
        '.git',
        'Thumbs.db',
        "node_modules",
        ]

language = 'zh_CN'

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']
source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}
myst_heading_anchors = 4
myst_enable_extensions = [
        "attrs_inline",  # 给元素添加属性,比如图片宽度
        "colon_fence",
        "strikethrough",
        "tasklist",
]
html_css_files = [
        "custom.css"
        ]
todo_include_todos = True
suppress_warnings = [
    "myst.header",
    "myst.xref_missing",
    "myst.not_included",
    "toc.not_included",
]
