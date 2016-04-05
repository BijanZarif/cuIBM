/***************************************************************************//**
 * \file bodies.h
 * \author Anush Krishnan (anush@bu.edu)
 * \brief Declaration of the class \c bodies.
 */
#pragma once

#include "domain.h"
#include "parameterDB.h"
#include "body.h"

/**
 * \class bodies
 * \brief Contains information about bodies in the flow.
 */
class bodies
{
public:
	int  numBodies,   ///< number of bodies
	     totalPoints; ///< total number of boundary points (all bodies)

	bool bodiesMove;  ///< tells whether the body is moving or not

	cusp::array1d<int, cusp::device_memory>
		numPoints,    ///< number of points for each body
		offsets,      ///< array index of the first point of each body
		I,            ///< x-index of the cell in which a body point is located
		J;            ///< y-index of the cell in which a body point is located

	cusp::array1d<int, cusp::device_memory>
		startI,       ///< starting cell index of the bounding box of a body
		startJ,       ///< starting cell index of the bounding box of a body
		numCellsX,    ///< number of cells in the x-direction in the bounding box of a body
		numCellsY;    ///< number of cells in the y-direction in the bounding box of a body

	cusp::array1d<double, cusp::device_memory>
		xmin,  ///< lowest x-coordinate for the bounding box of a body
		xmax,  ///< highest x-coordinate for the bounding box of a body
		ymin,  ///< lowest y-coordinate for the bounding box of a body
		ymax;  ///< highest y-coordinate for the bounding box of a body

	cusp::array1d<double, cusp::device_memory>
		forceX,		///< force acting on a body in the x-direction
		forceY;		///< force acting on a body in the y-direction

	cusp::array1d<double, cusp::device_memory>
		X,     ///< reference x-coordinates of the boundary points
		Y,     ///< reference y-coordinates of the boundary points
		ds,    ///< vector containing the lengths of all the boundary segments
		ones,  ///< vector of size \link totalPoints \endlink with all elements 1
		x,     ///< actual x-coordinate of the boundary points
		y,     ///< actual y-coordinate of the boundary points
		uB,    ///< x-velocity of the boundary points
		vB;    ///< y-velocity of the boundary points

    cusp::array1d<double, cusp::device_memory>
		xk,	//x-coordinate of boundary points at substep k
		yk,	//y-coordinate of boundary points at substep k
	    xkp1,	//x-coordinate of boundary points at substep k+1
	    ykp1;	//y-coordinate of boundary points at substep k+1

	cusp::array1d<double, cusp::device_memory>
		uBk,	//x-velocity of boundary points at substep k
		vBk;	//y-velocity of boundary points at substep k

	cusp::array1d<bool, cusp::device_memory>
		converged;

	cusp::array1d<double, cusp::device_memory>
		test;

	double centerVelocityU,
	     centerVelocityV; // need to initialise these fools

	// set initial position and velocity of each body
	void initialise(parameterDB &db, domain &D);

	// store index of each cell that contains a boundary point
	void calculateCellIndices(domain &D);

	// store indices of the bounding box of each body
	void calculateBoundingBoxes(parameterDB &db, domain &D);

	// update position, velocity and neighbors of each body
	void update(parameterDB &db, domain &D, double Time);

	// write body coordinates into a file
	void writeToFile(std::string &caseFolder, int timeStep);

	// write body coordinates into a file called \a bodies
	void writeToFile(double *bx, double *by, std::string &caseFolder, int timeStep);
};
