restructured
============

.. toctree::

    ./markdown.md

text style
----------

*斜体*: ``*``

**加粗**: ``**``

``block``: ``````


链接
----

`内部链接 <https://www.sphinx-doc.org/en/master/usage/restructuredtext/basics.html#hyperlinks>`_

.. code::

    `内部链接 <https://www.sphinx-doc.org/>`_

如果你都是中文，前后无法有空格, 就要用转义符. 比如\ 百度_\ 的网址

.. _百度: https://www.baidu.com


wikipedia参考_

.. _wikipedia参考: https://zh.m.wikipedia.org/zh-sg/ReStructuredText

source_

.. _source: https://docutils.sourceforge.io/rst.html

sphinx_

.. _sphinx: https://www.sphinx-doc.org/en/master/usage/restructuredtext/index.html

标题用=
-------

三级标题
^^^^^^^^

四级标题
~~~~~~~~

五级标题
""""""""

.. code::

    https://devguide.python.org/documentation/markup/#sections
    标题用= sections
    =======
    二级标题 subsections
    --------
    后面是
    ^^^^^ subsubsections
    ~~~~~~ 这个波浪号不再python规范里， 但是有用
    """""" paragraph


代码用'.. code::'
    
.. code::

    .. code::

        这里是代码

列表
----

列表用:

- 无序列表用-

.. code::

    - 无序列表用-

#) 自增

.. code::

    #) 自曾

#) 自增

10) 设置自增ID

代办事项
--------

.. todo::
   
   代办事项todo  
   wer

include
-------

include会直接复制过来
但是超过了级别不行

.. include:: ./same_include.rst
.. include:: ./include.rst

toctree会当作上面的最后一个标题的子元素

.. toctree::

   ./new_chapter.rst

- 我想toctree但是当作大标题, 不行

.. toctree::
   :caption: 2

   ./new_chapter2.rst
