cuIBM - A GPU-based Immersed Boundary Method code
=================================================

This is a fork of the [Barba group](https://github.com/barbagroup)'s
[cuIBM](https://github.com/barbagroup/cuIBM).
This version of cuIBM has been tested on CentOS 6.7 with CUDA 7.5 and cusp 0.5.1.

### New Features:
Fluid Structure interaction.

Installation instructions
-------------------------

### Dependencies

Please ensure that the following dependencies are installed before compiling
cuIBM:

* Git distributed version control system (`git`)
* GNU C++ Compiler(`g++`)
* NVIDIA's CUDA Compiler (`nvcc`)
* CUSP Library (available [here](https://github.com/cusplibrary/cusplibrary))

#### Git (`git`)

Install `git`. On Ubuntu, this can be done via the Terminal using the following
command:

    > sudo apt-get install git-core

#### GNU C++ Compiler (`g++`)

Install `g++` using the following command:

    > sudo apt-get install g++

Check the version of G++ installed:

    > g++ --version

Other development and version control tools can be installed by following the
instructions under Step 1 in the
[CompilingEasyHowTo](https://help.ubuntu.com/community/CompilingEasyHowTo) page
on the Ubuntu Community Help Wiki. Software developers will find it useful to
install all of them.

#### NVIDIA's CUDA Compiler (`nvcc`)

[Download and install](https://developer.nvidia.com/cuda-downloads) the CUDA
Toolkit.

Check the version of NVCC installed:

    > nvcc --version

cuIBM is being developed with NVCC version 7.5 and gcc 4.4.7.

**IMPORTANT**: `nvcc-4.1` is compatible only with G++ version 4.5 (`g++-4.5`)
or below. `nvcc-4.2` and above are compatible with `g++-4.6` and below.

#### CUSP Library

CUSP is a library that provides routines to perform sparse linear algebra
computations on Graphics Processing Units. It is written using the CUDA
programming language and runs code on compatible NVIDIA GPUs.

CUSP is currently hosted on
[GitHub](https://github.com/cusplibrary/cusplibrary). cuIBM has been tested
and works with version 0.5.1, available for download
[here](https://github.com/cusplibrary/cusplibrary/archive/0.5.1.zip).

The instructions here assume that the CUSP library is to be installed in the
folder `$HOME/lib`, but any other folder with write permissions can be used.
Create a local copy of the CUSP library using the following commands:

    > mkdir -p $/scratch/src/lib
    > cd /scratch/src/lib
    > wget https://github.com/cusplibrary/cusplibrary/archive/0.5.1.zip
    > unzip 0.5.1.zip

The folder `$HOME/lib/cusplibrary-0.5.1` is now created.

### Compiling cuIBM

This version of cuIBM can be found at its [GitHub repository](https://github.com/chrisminar/cuIBM).

Run the following commands to create a local copy of the repository in the
folder `/scratch/src` (or any other folder with appropriate read/write/execute
permissions):

    > cd /scratch/src
    > git clone https://github.com/Niemeyer-Research-Group/cuIBM.git

To compile, set the environment variable `CUSP_DIR` to point to the directory
with the CUSP library. For a `bash` shell, add the following line to the file
`~/.bashrc` or `~/.bash_profile`:

    export CUSP_DIR=/path/to/cusp/folder

which for the present case would be `$HOME/lib/cusplibrary-0.5.1`.

We also recommend setting the environment variable `CUIBM_DIR` to point to the
location of the cuIBM folder. While the code can be compiled and run without
setting this variable, some of the validation scripts provided make use of it.

    export CUIBM_DIR=/path/to/cuIBM/folder

which is `/scratch/src/cuIBM`, as per the above instructions.

Reload the file:

    > source ~/.bashrc

Switch to the cuIBM directory:

    > cd /scratch/src/cuIBM/src

Compile all the files:

    > make

Run a test:

    > make lidDrivenCavityRe100

**IMPORTANT**: If your NVIDIA card supports only compute capability 1.3, buy a new computer.  
Otherwise, edit Line 13 of the file `Makefile.inc` in the cuIBM root directory before
compiling: replace `compute_20` with `compute_13`.

Numerical schemes
-----------------

### Temporal discretisation

The following schemes have been tested for the available solvers:

* Convection
    - `ADAMS_BASHFORTH_2`: Second-order Adams-Bashforth

* Diffusion
    - `CRANK_NICOLSON`: Crank-Nicolson

### Spatial discretisation

The convection terms are calculated using a conservative symmetric
finite-difference scheme, and the diffusion terms are calculated using a
second-order central difference scheme.

Examples
--------

The following are available in the default installation:

lidDrivenCavityRe + ###
Example: lidDrivenCavityRe100
* `100`: Flow in a lid-driven cavity with Reynolds number
100.
* `1000`: Flow in a lid-driven cavity with Reynolds number
1000.
* `10000`: Flow in a lid-driven cavity with Reynolds number
10000.
cylinderRe + ###
Example : cylinderRe40
* `40`: Flow over a circular cylinder at Reynolds number 40. The
flow eventually reaches a steady state.
* `75`: Flow over a circular cylinder at Reynolds number 75. The
initial flow field has an asymmetric perturbation that triggers instability in
the flow and vortex shedding is observed in the wake.
* `100`: Flow over a circular cylinder at Reynolds number 100. The
initial flow field has an asymmetric perturbation that triggers instability in
the flow and vortex shedding is observed in the wake.
* `150`: Flow over a circular cylinder at Reynolds number 150. The
initial flow field has an asymmetric perturbation that triggers instability in
the flow and vortex shedding is observed in the wake.
* `550`: Initial flow over an impulsively started cylinder at
Reynolds number 550.
* `3000`: Initial flow over an impulsively started cylinder at
Reynolds number 3000.

### Run the tests

Post-processing
---------------

The only currently available post-processing script is
`$CUIBM_DIR/scripts/python/plotVorticity.py`. It plots the vorticity field of
the flow at all the saved time steps. To display a list of all the command line
options (which include the case folder, and the coordinates of the corners of
the region of interest), run:

    > python $CUIBM_DIR/scripts/python/plotVorticity.py --help

To obtain the vorticity plots, navigate to a case folder (or specify it using
the command line option) and run the script:

    > python $CUIBM_DIR/scripts/python/plotVorticity.py

Known issues
------------

* 

Contact
-------

Please e-mail [Chris Minar](mailto:minarc@oregonstate.edu) if you have any
questions, suggestions or feedback.
