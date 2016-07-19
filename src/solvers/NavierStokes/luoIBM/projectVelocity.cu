/***************************************************************************//**
 * \file
 * \author Christopher Minar (minarc@oregonstate.edu)
 * \brief functions to invoke the kernels that update the velocity
 */
#include <solvers/NavierStokes/luoIBM.h>

#include <solvers/NavierStokes/luoIBM/kernels/projectVelocity.h>
#include <solvers/NavierStokes/luoIBM/kernels/biLinearInterpolation.h>
#include <solvers/NavierStokes/oscCylinder/kernels/intermediateVelocity.h>//set inside
void luoIBM::velocityProjection()
{
	logger.startTimer("Velocity Projection");

	const int blocksize = 256;
	dim3 dimGridU( int( ((nx-1)*ny-0.5)/blocksize ) +1, 1);
	dim3 dimBlockU(blocksize, 1);
	dim3 dimGridV( int( (nx*(ny-1)-0.5)/blocksize ) +1, 1);
	dim3 dimBlockV(blocksize, 1);

	//project velocity
	kernels::project_velocity_luo_X<<<dimGridU,dimBlockU>>>(u_r, uhat_r, uold_r, pressure_r, dx_r, dt, nx, ny);
	kernels::project_velocity_luo_Y<<<dimGridV,dimBlockV>>>(u_r, uhat_r, uold_r, pressure_r, dy_r, dt, nx, ny);

	//force inside velocity to be body velocity...

	/*dim3 grid( int( (B.numCellsXHost*B.numCellsYHost-0.5)/blocksize ) +1, 1);
	dim3 block(blocksize, 1);
	kernels::interpolateVelocityToGhostNodeX<<<grid,block>>>(u_r, ghostTagsUV_r, B.x_r, B.y_r, B.uB_r, yu_r, xu_r,
													body_intercept_x_r, body_intercept_y_r, image_point_x_r, image_point_y_r,
													B.startI_r, B.startJ_r, B.numCellsXHost, nx, ny,
													x1_r,x2_r,x3_r,x4_r,y1_r,y2_r,y3_r,y4_r,q1_r,q2_r,q3_r,q4_r, image_point_u_r);
	kernels::interpolateVelocityToGhostNodeY<<<grid,block>>>(u_r, ghostTagsUV_r, B.x_r, B.y_r, B.vB_r, yv_r, xv_r,
													body_intercept_x_r, body_intercept_y_r, image_point_x_r, image_point_y_r,
													B.startI_r, B.startJ_r, B.numCellsXHost, nx, ny,
													x1_r,x2_r,x3_r,x4_r,y1_r,y2_r,y3_r,y4_r,q1_r,q2_r,q3_r,q4_r, image_point_u_r);

	dim3 grid2( int( ((nx-1)*ny-0.5)/blocksize ) +1, 1);
	kernels::setInsideVelocity<<<grid2,block>>>(ghostTagsUV_r, u_r, B.uB_r, B.vB_r, nx, ny);
	//testInterpX();
*/
	logger.stopTimer("Velocity Projection");
}
