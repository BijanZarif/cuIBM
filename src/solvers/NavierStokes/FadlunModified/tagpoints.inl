/***************************************************************************//**
 * \file tagPoints.inl
 * \author Anush Krishnan (anush@bu.edu), Christopher Minar (minarc@oregonstate.edu)
 * \brief Implementation of the methods of the class \c DirectForcingSolver to tag
 *        points near the immersed boundary using a ray-tracing algorithm.
 */

/**
 * \brief Tags the forcing nodes among the velocity nodes, i.e. the nodes at 
 *        which the velocity interpolation is performed.
 */
#include <solvers/NavierStokes/FadlunModified/kernels/tagPoints.h>
#include <cusp/print.h>

void fadlunModified::tagPoints()
{
	logger.startTimer("tagPoints");
	int  nx = NavierStokesSolver::domInfo->nx,
		 ny = NavierStokesSolver::domInfo->ny,
		 totalPoints = B.totalPoints,
		 i_start = B.startI[0],
		 j_start = B.startJ[0],
		 width_i = B.numCellsX[0],
		 height_j = B.numCellsY[0],
		 i_end = i_start + width_i,
		 j_end = j_start + height_j;
	
	double	*pressure_r = thrust::raw_pointer_cast ( &(pressure[0]) ),
			*bx_r		= thrust::raw_pointer_cast ( &(B.x[0]) ),//not sure if these are on the host or not
			*by_r		= thrust::raw_pointer_cast ( &(B.y[0]) ),
			*uB_r		= thrust::raw_pointer_cast ( &(B.uB[0]) ),
			*vB_r		= thrust::raw_pointer_cast ( &(B.vB[0]) ),
			*yu_r		= thrust::raw_pointer_cast ( &(NavierStokesSolver::domInfo->yu[0]) ),
			*xu_r		= thrust::raw_pointer_cast ( &(NavierStokesSolver::domInfo->xu[0]) ),
			*yv_r		= thrust::raw_pointer_cast ( &(NavierStokesSolver::domInfo->yv[0]) ),
			*xv_r		= thrust::raw_pointer_cast ( &(NavierStokesSolver::domInfo->xv[0]) ),
			*a_r		= thrust::raw_pointer_cast ( &(distance_from_intersection_to_node[0]) ),
			*b_r		= thrust::raw_pointer_cast ( &(distance_between_nodes_at_IB[0]) ),
			*dub_r		= thrust::raw_pointer_cast ( &(distance_from_u_to_body[0]) ),
			*dvb_r		= thrust::raw_pointer_cast ( &(distance_from_v_to_body[0]) ),
			*uv_r		= thrust::raw_pointer_cast ( &(uv[0]) );
	
	int 	*tags_r		= thrust::raw_pointer_cast ( &(tags[0]) ),
			*tags2_r	= thrust::raw_pointer_cast ( &(tags2[0]) ),
			*tagsIn_r	= thrust::raw_pointer_cast ( &(tagsIn[0]) ),
			*tagsP_r	= thrust::raw_pointer_cast ( &(tagsP[0]) ),
			*tagsPOut_r	= thrust::raw_pointer_cast ( &(tagsPOut[0]) ),
			*tagsPOld_r = thrust::raw_pointer_cast ( &(tagsPOld[0]) );
	
	//testing
	tagsOld = tags;
	tagsPOld = tagsPOut;
	cusp::blas::fill(tags, -1);
	cusp::blas::fill(tags2, -1);
	cusp::blas::fill(tagsIn, -1);
	cusp::blas::fill(tagsP, -1);
	cusp::blas::fill(tagsPOut, -1);
	cusp::blas::fill(distance_from_intersection_to_node, 1);
	cusp::blas::fill(distance_between_nodes_at_IB, 1);
		
	const int blocksize = 256;
	dim3 dimGrid( int( (width_i*height_j-0.5)/blocksize ) +1, 1);
	dim3 dimBlock(blocksize, 1);
	dim3 dimGrid0(int( (i_end-i_start-0.5)/blocksize ) +1, 1);
	
	//tag u direction nodes for tags, tagsout and tags2
	kernels::tag_u<<<dimGrid,dimBlock>>>(tags_r, tagsIn_r, tags2_r,
										   bx_r, by_r, uB_r, vB_r, yu_r, xu_r, a_r, b_r, dub_r, dvb_r, uv_r, 
										   i_start, j_start, i_end, j_end, nx, ny, totalPoints, B.midX, B.midY);
	//tag v direction nodes for tags, tagsout and tag2
	kernels::tag_v<<<dimGrid,dimBlock>>>(tags_r, tagsIn_r, tags2_r,
										   bx_r, by_r, uB_r, vB_r, yv_r, xv_r, a_r, b_r, dub_r, dvb_r, uv_r, 
										   i_start, j_start, i_end, j_end, nx, ny, totalPoints, B.midX, B.midY);
	//tag pressure nodes for tagsp and tagspout
	kernels::tag_p<<<dimGrid,dimBlock>>>(tagsP_r, tagsPOut_r,
											bx_r, by_r, yu_r, xv_r, 
											i_start, j_start, i_end, j_end, nx, ny, totalPoints, B.midX, B.midY);
	//zero the inside of tagsp
	kernels::zero_pressure<<<dimGrid0, dimBlock>>>(tagsP_r, i_start, j_start, i_end, j_end, nx, ny);
	//zero the inside of tagsinx
	kernels::zero_x<<<dimGrid0,dimBlock>>>(tagsIn_r, i_start, j_start, i_end, j_end, nx, ny);
	//zero the inside of tagsiny
	kernels::zero_y<<<dimGrid0,dimBlock>>>(tagsIn_r, i_start, j_start, i_end, j_end, nx, ny);
	
	//testing //flag
	double a = thrust::reduce(tagsOld.begin(),tagsOld.end()-nx*(ny-1)),
		   b = thrust::reduce(tags.begin(), tags.end()-nx*(ny-1)),
		   c = thrust::reduce(tagsOld.end()-nx*(ny-1), tagsOld.end()),
		   d = thrust::reduce(tags.end()-nx*(ny-1), tags.end()),
		   f = thrust::reduce(tagsPOld.begin(), tagsPOld.end()),
		   g = thrust::reduce(tagsPOut.begin(), tagsPOut.end());

	if (timeStep>0)
	{
	if (a!=b)
	{
		std::cout<<"tags x changed at " << timeStep<<"\n";
		//arrayprint(tags,"tagsx","x");
		//arrayprint(tagsOld,"tagsOldx","x");
	}
	if (c!=d)
	{
		std::cout<<"tags y changed at " << timeStep<<"\n";
		//arrayprint(tags,"tagsy","y");
		//arrayprint(tagsOld,"tagsOldy","y");
	}
	if (f!=g)
	{
		std::cout<<"tags p changed at " << timeStep<<"\n";
		//arrayprint(tagsPOut,"tagsp","p");
		//arrayprint(tagsPOld,"tagsPOldx","p");
	}
	}
	logger.stopTimer("tagPoints");
}