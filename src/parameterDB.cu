/***************************************************************************//**
 * \file parameterDB.cu
 * \author Anush Krishnan (anush@bu.edu)
 * \brief Implementation of the methods of the class \c property.
 */


#include "parameterDB.h"
#include "boundaryCondition.h"
#include "body.h"
#include "preconditioner.h"
#include "types.h"

/**
 * \brief Converts a number to a string.
 *
 * \param num a number
 *
 * \return a string
 */
template <typename T>
std::string toString(T num)
{
  std::stringstream ss; 
  ss << num;
  return ss.str();
}

/**
 * \brief Converts a type of boundary condition to a string.
 *
 * \param b a type of boundary condition (\c bcType)
 *
 * \return a string
 */
template <>
std::string toString(bcType b)
{
  if (b == DIRICHLET)
    return "Dirichlet";
  else if (b == NEUMANN)
    return "Neumann";
  else if (b == CONVECTIVE)
    return "Convective";
  else
    return "Error";
}

template<>
std::string toString(solverType b)
{
	if (b == NAVIERSTOKES)
		return "Navier Stokes";
	else if (b == FADLUN)
		return "Fadlun";
	else if (b == OSC)
		return "Oscillating Cylinders";
	else if (b == FSI)
		return "Fluid Structure Interaction";
	else if (b == LUO)
		return "LUO";
	else
		return "error";
}

/**
 * \brief Gets the value of the property as a string.
 *
 * \return the value of the property as a string
 */
template <>
std::string property::get()
{
  return std::string(value);
}

/**
 * \brief Gets the value of the property as a given type.
 *
 * \return the value of the property as a given type
 */
template <typename T>
T property::get()
{
  T r = *reinterpret_cast<T*>(&value[0]);
  return r;
}

// explicit instantiations of the method property::get()
// to be able to define the template function outside the header file
template double property::get<double>();
template float property::get<float>();
template int property::get<int>();
template bool property::get<bool>();
template preconditionerType property::get<preconditionerType>();
template solverType property::get<solverType>();
template std::vector<body> *property::get<std::vector<body>*>();
template boundaryCondition **property::get<boundaryCondition **>();

/*
body property::get<std::vector<body> *>()
{
	body r = *reinterpret_cast<body*>(&value[0]);
	return r;
}

boundaryCondition property::get<boundaryCondition **>()
{
	boundaryCondition r = *reinterpret_cast<boundaryCondition*>(&value[0]);
	return r;
}*/

/**
 * \brief Returns a string describing the value of property as appropriate.
 *
 * \return a constant character pointer
 */
const char *property::print()
{ 
    if (*type == typeid(int))
      return toString(this->get<int>()).c_str();
    else if (*type == typeid(double))
      return toString(this->get<double>()).c_str();
	else if (*type == typeid(float))
      return toString(this->get<float>()).c_str();
    else if (*type == typeid(std::string))
      return (const char *)value;
    else
      return "not found";
}

/**
 * \brief Sets the value of the property given a string.
 *
 * \param s a string
 */
template <>
void property::set(std::string s)
{
  strncpy(value, s.c_str(), 256);
}

/**
 * \brief Sets the value of the property given a type.
 *
 * \param v the value
 */
template <typename T>
void property::set(T v)
{
  // assume we have enough space (256 bytes)
  type = &typeid(T);
  *reinterpret_cast<T*>(&value[0]) = v;
}

// explicit instantiations of the method property::set()
// to be able to define the template function outside the header file
template void property::set(int v);
template void property::set(float v);
template void property::set(double v);
template void property::set(bool v);
template void property::set(preconditionerType v);
template void property::set(solverType v);
template void property::set(boundaryCondition **v);
template void property::set(std::vector<body> *v);
