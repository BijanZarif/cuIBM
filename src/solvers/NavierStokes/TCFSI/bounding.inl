/***************************************************************************//**
 * \file bounding.inl
 * \author Anush Krishnan (anush@bu.edu)
 * \brief Implementation of the methods of the class \c TCFSISolver
 *        calculate bounding box and cell indices
 */

/**
 *
 */
template <typename memoryType>
void TCFSISolver<memoryType>::calculateCellIndices(domain &D)
{
	int	i=0, j=0;

	// find the cell for the zeroth point
	while(D.x[i+1] < NSWithBody<memoryType>::B.xk[0])
		i++;
	while(D.y[j+1] < NSWithBody<memoryType>::B.yk[0])
		j++;
	NSWithBody<memoryType>::B.I[0] = i;
	NSWithBody<memoryType>::B.J[0] = j;

	for(int k=1; k<NSWithBody<memoryType>::B.totalPoints; k++)
	{
		// if the next boundary point is to the left of the current boundary point
		if(NSWithBody<memoryType>::B.xk[k] < NSWithBody<memoryType>::B.xk[k-1])
		{
			while(D.x[i] > NSWithBody<memoryType>::B.xk[k])
				i--;
		}
		// if the next boundary point is to the right of the current boundary point
		else
		{
			while(D.x[i+1] < NSWithBody<memoryType>::B.xk[k])
				i++;
		}
		// if the next boundary point is below the current boundary point
		if(NSWithBody<memoryType>::B.yk[k] < NSWithBody<memoryType>::B.yk[k-1])
		{
			while(D.y[j] > NSWithBody<memoryType>::B.yk[k])
				j--;
		}
		// if the next boundary point is above the current boundary point
		else
		{
			while(D.y[j+1] < NSWithBody<memoryType>::B.yk[k])
				j++;
		}
		NSWithBody<memoryType>::B.I[k] = i;
		NSWithBody<memoryType>::B.J[k] = j;
	}
}

/**
 *
 */
template <typename memoryType>
void TCFSISolver<memoryType>::calculateBoundingBoxes(parameterDB &db, domain &D)
{
	real scale = db["simulation"]["scaleCV"].get<real>(),
	     dx, dy;
	int  i, j;
	for(int k=0; k<NSWithBody<memoryType>::B.numBodies; k++)
	{
		NSWithBody<memoryType>::B.xmin[k] = NSWithBody<memoryType>::B.xk[NSWithBody<memoryType>::B.offsets[k]];
		NSWithBody<memoryType>::B.xmax[k] = NSWithBody<memoryType>::B.xmin[k];
		NSWithBody<memoryType>::B.ymin[k] = NSWithBody<memoryType>::B.yk[NSWithBody<memoryType>::B.offsets[k]];
		NSWithBody<memoryType>::B.ymax[k] = NSWithBody<memoryType>::B.ymin[k];
		for(int l=NSWithBody<memoryType>::B.offsets[k]+1; l<NSWithBody<memoryType>::B.offsets[k]+NSWithBody<memoryType>::B.numPoints[k]; l++)
		{
			if(NSWithBody<memoryType>::B.xk[l] < NSWithBody<memoryType>::B.xmin[k]) NSWithBody<memoryType>::B.xmin[k] = NSWithBody<memoryType>::B.xk[l];
			if(NSWithBody<memoryType>::B.xk[l] > NSWithBody<memoryType>::B.xmax[k]) NSWithBody<memoryType>::B.xmax[k] = NSWithBody<memoryType>::B.xk[l];
			if(NSWithBody<memoryType>::B.yk[l] < NSWithBody<memoryType>::B.ymin[k]) NSWithBody<memoryType>::B.ymin[k] = NSWithBody<memoryType>::B.yk[l];
			if(NSWithBody<memoryType>::B.yk[l] > NSWithBody<memoryType>::B.ymax[k]) NSWithBody<memoryType>::B.ymax[k] = NSWithBody<memoryType>::B.yk[l];
		}
		dx = NSWithBody<memoryType>::B.xmax[k]-NSWithBody<memoryType>::B.xmin[k];
		dy = NSWithBody<memoryType>::B.ymax[k]-NSWithBody<memoryType>::B.ymin[k];
		NSWithBody<memoryType>::B.xmax[k] += 0.5*dx*(scale-1.0);
		NSWithBody<memoryType>::B.xmin[k] -= 0.5*dx*(scale-1.0);
		NSWithBody<memoryType>::B.ymax[k] += 0.5*dy*(scale-1.0);
		NSWithBody<memoryType>::B.ymin[k] -= 0.5*dy*(scale-1.0);
		
		i=0; j=0;
		while(D.x[i+1] < NSWithBody<memoryType>::B.xmin[k])
			i++;
		while(D.y[j+1] < NSWithBody<memoryType>::B.ymin[k])
			j++;
		NSWithBody<memoryType>::B.startI[k] = i;
		NSWithBody<memoryType>::B.startJ[k] = j;
		
		while(D.x[i] < NSWithBody<memoryType>::B.xmax[k])
			i++;
		while(D.y[j] < NSWithBody<memoryType>::B.ymax[k])
			j++;
		NSWithBody<memoryType>::B.numCellsX[k] = i - NSWithBody<memoryType>::B.startI[k];
		NSWithBody<memoryType>::B.numCellsY[k] = j - NSWithBody<memoryType>::B.startJ[k];
	}
}



