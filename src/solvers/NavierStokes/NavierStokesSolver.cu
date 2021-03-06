/***************************************************************************//**
 * \file NavierStokesSolver.cu
 * \author Anush Krishnan (anush@bu.edu), Christopher Minar (minarc@oreonstate.edu)
 * \brief Implementation of the methods of the class \c NavierStokesSolver.
 */

#include "NavierStokesSolver.h"
#include "NavierStokes/kernels/initialise.h"
#include <sys/stat.h>
#include <io/io.h>
#include <cusp/precond/aggregation/smoothed_aggregation.h>//flag
#include <cusp/krylov/cg.h>//flag
#include <cusp/krylov/bicgstab.h>
#include <cusp/krylov/gmres.h>//flag
#include <cusp/krylov/bicg.h>//flag
#include <cusp/print.h>//flag
#include <cusp/blas/blas.h>//flag

#include <iostream>
#include <fstream>

//##############################################################################
//                              INITIALISE
//##############################################################################

/**
 * \brief Initializes parameters, arrays and matrices required for the simulation.
 */

/* initialise the simulation
 *
 */
void NavierStokesSolver::initialise()
{
	logger.startTimer("initialise");
	initialiseNoBody();
	initialiseLHS();
	logger.stopTimer("initialise");
}

/* intialise the parts of the simulation that share no similarities to a body solver
 *
 */
void NavierStokesSolver::initialiseNoBody()
{
	printf("NS initalising\n");
	int nx = domInfo->nx,
		ny = domInfo->ny;

	int numUV = (nx-1)*ny + nx*(ny-1);
	int numP  = nx*ny;

	//////////////////////////////////////////////////////////////////////////////////////////////////
	//COMMON STUFF
	//////////////////////////////////////////////////////////////////////////////////////////////////
	// initial values of timeStep
	timeStep = (*paramDB)["simulation"]["startStep"].get<int>();

	// creates directory
	std::string folder = (*paramDB)["inputs"]["caseFolder"].get<std::string>();
	io::makeDirectory(folder);;

	// writes the grids information to a file
	io::writeGrid(folder, *domInfo);

	std::cout << "Initialised common stuff!" << std::endl;

	////////////////////////////////////////////////////////////////////////////////////////////////
	//ARRAYS
	////////////////////////////////////////////////////////////////////////////////////////////////
	//Doubles, size uv, device
	u.resize(numUV);
	uhat.resize(numUV);
	uold.resize(numUV);
	N.resize(numUV);
	Nold.resize(numUV);
	L.resize(numUV);
	Lnew.resize(numUV);
	rhs1.resize(numUV);
	bc1.resize(numUV);

	//doubles, size np, device
	pressure.resize(numP);
	rhs2.resize(numP);
	pressure_old.resize(numP);

	cusp::blas::fill(rhs2, 0);//flag
	cusp::blas::fill(uhat, 0);//flag
	cusp::blas::fill(Nold, 0);//flag
	cusp::blas::fill(N, 0);//flag
	std::cout<<"Initialised Arrays!" <<std::endl;

	///////////////////////////////////////////////////////////////////////////////////////////////
	//Initialise velocity arrays
	///////////////////////////////////////////////////////////////////////////////////////////////

	double	uInitial = (*paramDB)["flow"]["uInitial"].get<double>(),
			vInitial = (*paramDB)["flow"]["vInitial"].get<double>(),
			uPerturb = (*paramDB)["flow"]["uPerturb"].get<double>(),
			vPerturb = (*paramDB)["flow"]["vPerturb"].get<double>(),
			xmin = domInfo->x[0],
			xmax = domInfo->x[nx-1],
			ymin = domInfo->y[0],
			ymax = domInfo->y[ny-1];
	const int blocksize = 256;
	dim3 dimGridU( int( ((nx-1)*ny-0.5)/blocksize ) +1, 1);
	dim3 dimBlock(blocksize, 1);
	dim3 dimGridV( int( (nx*(ny-1)-0.5)/blocksize ) +1, 1);

	double *u_r		= thrust::raw_pointer_cast( &(u[0]) ),
		   *xu_r	= thrust::raw_pointer_cast( &(domInfo->xu[0]) ),
		   *xv_r	= thrust::raw_pointer_cast( &(domInfo->xv[0]) ),
		   *yu_r	= thrust::raw_pointer_cast( &(domInfo->yu[0]) ),
		   *yv_r	= thrust::raw_pointer_cast( &(domInfo->yv[0]) );

	kernels::initialiseU<<<dimGridU,dimBlock>>>(u_r, xu_r, yu_r, uInitial, uPerturb, M_PI, xmax, xmin, ymax, ymin, nx, ny);
	kernels::initialiseV<<<dimGridV,dimBlock>>>(u_r, xv_r, yv_r, vInitial, vPerturb, M_PI, xmax, xmin, ymax, ymin, nx, ny);

	uhat=u;

	std::cout<<"Initialised Velocities!" <<std::endl;

	/////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//Initialise boundary condition arrays
	/////////////////////////////////////////////////////////////////////////////////////////////////////////////
	boundaryCondition
		**bcInfo
		 = (*paramDB)["flow"]["boundaryConditions"].get<boundaryCondition **>();

	//resize boundary arrays by the number of velocity points on boundaries (u and v points)
	bc[XMINUS].resize(2*ny-1);
	bc[XPLUS].resize(2*ny-1);
	bc[YMINUS].resize(2*nx-1);
	bc[YPLUS].resize(2*nx-1);

	//Top and Bottom
	for(int i=0; i<nx-1; i++)
	{
		bc[YMINUS][i] = bcInfo[YMINUS][0].value;
		bc[YPLUS][i]  = bcInfo[YPLUS][0].value;
		bc[YMINUS][i+nx-1]	= bcInfo[YMINUS][1].value;
		bc[YPLUS][i+nx-1]	= bcInfo[YPLUS][1].value;
	}
	bc[YMINUS][2*nx-2]	= bcInfo[YMINUS][1].value;
	bc[YPLUS][2*nx-2]	= bcInfo[YPLUS][1].value;

	/// Left and Right
	for(int i=0; i<ny-1; i++)
	{
		bc[XMINUS][i] = bcInfo[XMINUS][0].value;
		bc[XPLUS][i]  = bcInfo[XPLUS][0].value;
		bc[XMINUS][i+ny] = bcInfo[XMINUS][1].value;
		bc[XPLUS][i+ny]  = bcInfo[XPLUS][1].value;
	}
	bc[XMINUS][ny-1] = bcInfo[XMINUS][0].value;
	bc[XPLUS][ny-1]  = bcInfo[XPLUS][0].value;

	std::cout << "Initialised boundary conditions!" << std::endl;

	////////////////////////////////////////////////////////////////////////////////////////////////
	//OUTPUT
	////////////////////////////////////////////////////////////////////////////////////////////////
	std::stringstream outiter;
	outiter << folder << "/iterations";
	iterationsFile.open(outiter.str().c_str());
}

/*
 * Initialise the left hand sides of the velocity and poission solvers
 * create preconditioners
 */
void NavierStokesSolver::initialiseLHS()
{
	int nx = domInfo->nx,
		ny = domInfo->ny,
		numUV = (nx-1)*ny + (ny-1)*nx;
	LHS1.resize(numUV, numUV, (nx-1)*ny*5 - 2*ny-2*(nx-1)       +        (ny-1)*nx*5 - 2*(ny-1) - 2*nx);
	LHS2.resize(nx*ny, nx*ny, 5*nx*ny - 2*ny-2*nx);
	generateLHS1();
	generateLHS2();

	PC.generate(LHS1,LHS2, (*paramDB)["velocitySolve"]["preconditioner"].get<preconditionerType>(), (*paramDB)["PoissonSolve"]["preconditioner"].get<preconditionerType>());
	std::cout << "Assembled LHS matrices!" << std::endl;
}

//##############################################################################
//                            TIME STEPPING
//##############################################################################

/**
 * \brief Calculates the variables at the next time step.
 */
void NavierStokesSolver::stepTime()
{
	//1: Solve for intermediate velocity
	generateRHS1();
	//arrayprint(rhs1,"rhs1","x");
	solveIntermediateVelocity();
	//arrayprint(uhat,"uhat","x");
	//arrayprint(uhat,"vhat","y");

	//2: Solve for pressure correction
	generateRHS2();
	//arrayprint(rhs2,"rhs2","p");
	solvePoisson();
	//arrayprint(pressure,"pressure","p");

	//3: Project velocity
	velocityProjection();
	//arrayprint(u,"u","x");
	//arrayprint(u,"v","y");

	//4: update time
	timeStep++;
	if (timeStep%(*paramDB)["simulation"]["nsave"].get<int>() == 0)
	{
	}
	//std::cout<<"Timestep: "<<timeStep<<"\n";
}

/**
 * \brief Evaluates the condition required to stop the simulation.
 *
 * \return a Boolean to continue or stop the simulation
 */
bool NavierStokesSolver::finished()
{
	int nt = (*paramDB)["simulation"]["nt"].get<int>();
	return (timeStep < nt) ? false : true;
}

/**
 * \brief Constructor. Copies the database and information about the computational grid.
 *
 * \param pDB database that contains all the simulation parameters
 * \param dInfo information related to the computational grid
 */
NavierStokesSolver::NavierStokesSolver(parameterDB *pDB, domain *dInfo)
{
	paramDB = pDB;
	domInfo = dInfo;
}

//##############################################################################
//                           LINEAR SOLVES
//##############################################################################

/**
 * \brief Solves for the intermediate velocity.
 */

void NavierStokesSolver::solveIntermediateVelocity()
{
	logger.startTimer("solveIntermediateVel");
	int  maxIters = (*paramDB)["velocitySolve"]["maxIterations"].get<int>();
	double relTol = (*paramDB)["velocitySolve"]["tolerance"].get<double>();

	cusp::monitor<double> sys1Mon(rhs1,maxIters,relTol);//flag currently this takes much more time than it should.
	//cusp::krylov::bicgstab(LHS1, uhat, rhs1, sys1Mon, *PC.PC1);
	cusp::krylov::bicgstab(LHS1, uhat, rhs1, sys1Mon);

	iterationCount1 = sys1Mon.iteration_count();

	if (!sys1Mon.converged())
	{
		std::cout << "ERROR: Solve for uhat failed at time step " << timeStep << std::endl;
		std::cout << "Iterations   : " << iterationCount1 << std::endl;
		std::cout << "Residual norm: " << sys1Mon.residual_norm() << std::endl;
		std::cout << "Tolerance    : " << sys1Mon.tolerance() << std::endl;
		std::exit(-1);
	}

	logger.stopTimer("solveIntermediateVel");
}

/**
 * \brief Solves the Poisson system for the pressure (and the body forces if immersed body).
 */

void NavierStokesSolver::solvePoisson()
{
	logger.startTimer("solvePoisson");

	int  maxIters = (*paramDB)["PoissonSolve"]["maxIterations"].get<int>();
	double relTol   = (*paramDB)["PoissonSolve"]["tolerance"].get<double>();

	cusp::monitor<double> sys2Mon(rhs2, maxIters, relTol);
	cusp::krylov::bicgstab(LHS2, pressure, rhs2, sys2Mon, *PC.PC2);

	iterationCount2 = sys2Mon.iteration_count();
	if (!sys2Mon.converged())
	{
		std::cout << "ERROR: Solve for pressure failed at time step " << timeStep << std::endl;
		std::cout << "Iterations   : " << iterationCount2 << std::endl;
		std::cout << "Residual norm: " << sys2Mon.residual_norm() << std::endl;
		std::cout << "Tolerance    : " << sys2Mon.tolerance() << std::endl;
		std::exit(-1);
	}

	logger.stopTimer("solvePoisson");
}

//##############################################################################
//                               OUTPUT
//##############################################################################

/**
 * prints an array
 * param value the array
 * param type type of array, p, x, y
 */

void NavierStokesSolver::arrayprint(cusp::array1d<double, cusp::device_memory> value, std::string name, std::string type, int time)
{
	if (timeStep != time && time > 0) //set time to a negative number to always print
		return;
	logger.startTimer("output");
	int nx = domInfo->nx;
	int ny = domInfo->ny;

	int x_length = nx;
	int y_length = ny;
	int i = 0;
	int row_length = nx;
	int pad = 0;
	if (type == "x")
	{
		x_length = nx-1;
		row_length = (nx-1);
		pad = 0;
	}
	if (type == "y")
	{
		y_length = ny-1;
		row_length = nx;
		pad = (nx-1)*ny;
	}

	std::ofstream myfile;
	std::string folder = (*paramDB)["inputs"]["caseFolder"].get<std::string>();
	std::stringstream out;
	std::stringstream convert; convert << "/output/" << timeStep << name << ".csv";
	std::string folder_name = convert.str();
	out<<folder<<folder_name;
	myfile.open(out.str().c_str());
	myfile<<name<<"\n";
	for (int J = 0; J < y_length; J++)
	{
		for (int I = 0; I < x_length; I++)
		{
			i = row_length*J + I + pad;
			//myfile<<round(10000*value[i])/10000;
			myfile<<value[i];
			myfile<<'\t';
		}
		myfile<<"\n";
	}
	myfile.close();
	std::cout<<"printed "<<name <<"\n";
	logger.stopTimer("output");
}

void NavierStokesSolver::printLHS()
{
	logger.startTimer("output");
	int nx = domInfo->nx;
	int ny = domInfo->ny;

	std::ofstream myfile;
	std::string folder = (*paramDB)["inputs"]["caseFolder"].get<std::string>();
	std::stringstream out;
	std::stringstream convert; convert << "/output/" << timeStep << "LHS" << ".csv";
	std::string folder_name = convert.str();
	out<<folder<<folder_name;
	myfile.open(out.str().c_str());
	cusp::coo_matrix<int, double, cusp::host_memory> LHS = LHS2;
	std::cout<<"done copying LHS\n";
	int	idx = 0;
	for (int j=0; j < nx*ny; j++)
	{
		for (int i=0; i < nx*ny; i++)
		{
			//if we are at an occupied node
			if (i == LHS.column_indices[idx] && j == LHS.row_indices[idx])
			{
				myfile<<LHS.values[idx]<<"\t";
				idx +=1;
			}
			else
			{
				myfile<<"\t";
			}
		}
		myfile<<"\n";
	}
	myfile.close();
	std::cout<<"printed lhs\n";
	logger.stopTimer("output");
}

/**
 * \brief Writes numerical solution at current time-step,
 *        as well as the number of iterations performed in each solver.
 */
void NavierStokesSolver::writeCommon()
{

	int nsave = (*paramDB)["simulation"]["nsave"].get<int>();
	std::string folder = (*paramDB)["inputs"]["caseFolder"].get<std::string>();

	// write the velocity fluxes and the pressure values
	if (timeStep % nsave == 0)
		io::writeData(folder, timeStep, uhat, pressure, *domInfo);//, *paramDB);

	// write the number of iterations for each solve
	iterationsFile << timeStep << '\t' << iterationCount1 << '\t' << iterationCount2 << std::endl;
}

/**
 * \brief Writes data into files.
 */
void NavierStokesSolver::writeData()
{
	logger.startTimer("output");

	writeCommon();

	logger.stopTimer("output");
}

/**
 * \brief Prints timing information and closes the different files.
 */
void NavierStokesSolver::shutDown()
{
	io::printTimingInfo(logger);
	iterationsFile.close();
}

// include inline files
#include "NavierStokes/intermediateVelocity.inl"
#include "NavierStokes/intermediatePressure.inl"
#include "NavierStokes/projectVelocity.inl"
