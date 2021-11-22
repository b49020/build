####################
Functional Simulator
####################

.. contents::

TBD

Installation
************
Prerequisites
=============
This setup has dependencies to various packages. The list of packages that we've
been able to identify is as below and needs to be installed on your system:


Get the source code
===================
Install ``repo`` by following the installation instructions 
`here <https://source.android.com/setup/build/downloading>`_. Once repo has been
configured, it's time to initialize the tree.

.. code-block:: bash

    $ mkdir -p <path-to-my-project-root>
    $ cd <path-to-my-project-root>
    $ repo init -u https://github.com/jbech-linaro/manifest.git -b fun_sim

Next sync the actual tree

.. code-block:: bash

    $ repo sync -j4


Compile
=======
TBD

.. code-block:: bash

    $ make -j4

FAQ
***

.. _faq1:

1. TBD
===================================


// Joakim Bech
2021-11-22
