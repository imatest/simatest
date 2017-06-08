%     Copyright (C) 2017 Imatest LLC
% 
%     This program is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
% 
%     This program is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
% 
%     You should have received a copy of the GNU General Public License
%     along with this program.  If not, see <http://www.gnu.org/licenses/>.

classdef LensModel
   % The LensModel class simulates common observable effects on image quality from lenses from
   % standard mathematical models of those effects. It does NOT do any simulation based on light
   % spectra or ray tracing, rather it simply applies the effects of distortion, LCA, etc to an
   % input image according to the common models used to describe those effects.
   %
   % Input data to the .simulate() method should be 3-channel RGB data. Since this class does not
   % deal with spectra, it is simply assumed that these tri-stimulus values are affected by the
   % models described below. 
   % 
   %
   % - - Geometric Distortion - - 
   % The distortion model assumes radial distortion from the center of the image, described by a
   % 3rd- or 5th-order polynomial which maps from the true radial position to the distorted radial
   % position. This is not the same as the Local Geometric Distortion (LGD) description of radial
   % distortion, though it is possible to convert between the two. 
   %
   %
   % - - Lateral Chromatic Aberration - - 
   % The Lateral Chromatic Aberration (LCA) model assumes radial position errors of red and blue
   % channels relative to the green channel. Furthermore, it is assumed that this relative error is
   % described by a 3rd- or 5th-order polynomial which maps from relative displacement (aberration)
   % to radial distance.
   %
   % It is always assumed that the polynomials used are defined on the range [0, 1], with 1 being
   % the distance from the center of the image array (between pixels if even-sized height and width)
   % to the center of the pixel at the corner of the array (any corner).  Thus the radial
   % distortion polynomials are all on normalized radial coordinates, normalized using the
   % half-diagonal distance. 
   %
   % These polynomials are all defined in the code in the manner consistent with (and described by)
   % the MATLAB functions polyfit() and polyval(). Refer to those function help files for more.
   % 
   % See the IEEE-1858 CPIQ specification for more description of the LCA model.
   %
   % - - Optical Center Offset - - 
   % Both LCA and Geometric Distortion are radial in nature. The center of this distortion is the
   % 'optical center' of the lens, which by default is the same as the center of the array of the
   % scene data put in. However, you can specifyan amount, in real values in units of pixels, an 
   % offset from the center of the image array where the optical center actually falls. 
   %
   % Values are in "image coordinate" orientation, and so positive values, [dx, dy], indicate an
   % optical center which is towards the lower left of the image by the indicated amounts.
   %
   % - - Flare - - 
   % The flare model assumes that some portion of the light from each pixel gets spread evenly
   % around the image to every other pixel. (This portion is identified in this class as the
   % 'flareConstant', which should be in the range [0, 1].) 
   %
   % The model thus becomes that each input value is attenuated by flareConstant (i.e., scaled to 
   % value*(1-flareConstant)), and then the total energy that has been 'sapped' from all locations 
   % is then summed and distributed equally to all locations. Total amount of input signal is
   % preserved, just redistributed. 
   % 
   %
   % Flare is applied per-color channel, as a soft way of modeling that different wavelengths may
   % have different amounts of flare. (This is a bit of a hack.)
   %
   % 
   % See also: DummyLens
   
   properties
      distortionCoeffs % polynomial coeffs for forward radial distortion
      lcaCoeffs_rg    % polynomial coeffs for forward application of relative red-green radial aber.
      lcaCoeffs_bg   % polynomial coeffs for forward application of relative blue-green radial aber.
      flareConstant = 0;  % relative to the max of the scene, e.g. 1/1000
      opticalCenterOffset = [0,0]; % [dx,dy] offset from center of image array (real valued)
   end
   
   
   methods
      
      function obj = LensModel(varargin)
         % model = LensModel()
         % model = LensModel(name, value,...)
         %
         % Optional parameter pair-value pairs are: 
         %  'distortionCoeffs', polynomial coefficient vector, 3rd or 5th order
         %  'lcaCoeffs_rg', polynomial coefficient vector, 3rd or 5th order
         %  'lcaCoeffs_bg', polynomial coefficient vector, 3rd or 5th order
         %  'opticalCenterOffset', [dx, dy] array of real values
         %  'flareConstant', a real value in range [0,1]
         %
         % Default LensModel (or any subset of missing optional input parameters) results in a model
         % which has no distortion, no LCA, and no flare.
         
         % Parse inputs
         default_distortionCoeffs = [0 0 1 0]; % 3rd order polynomial identity function
         default_lcaCoeffs_rg = [0 0 0 0]; % nuthin'
         default_lcaCoeffs_bg = [0 0 0 0]; % nuthin'
         default_offset = [0,0];
         default_flareConstant = 0;
         
         parser = inputParser();
         parser.addParameter('distortionCoeffs',default_distortionCoeffs)
         parser.addParameter('lcaCoeffs_rg',default_lcaCoeffs_rg)
         parser.addParameter('lcaCoeffs_bg',default_lcaCoeffs_bg)
         parser.addParameter('flareConstant',default_flareConstant)
         parser.addParameter('offset', default_offset)
         parser.parse(varargin{:});
         params = parser.Results;
         
         obj.distortionCoeffs = params.distortionCoeffs;
         obj.lcaCoeffs_bg = params.lcaCoeffs_bg;
         obj.lcaCoeffs_rg = params.lcaCoeffs_rg;
         obj.flareConstant = params.flareConstant;
         obj.opticalCenterOffset = params.offset;
      end
      
      
      function sensorPlaneRadiantPower = simulate(obj,sceneRadiantPower)
         % sensorPlaneRadiance = simulate(obj,sceneRadiantPower)
         % 
         % - - Input - - 
         % sceneRadiantPower : MxNx3 array of real values, indicating the radiant power 
         %                    (photons/sec) in 3 color bands striking the front glass of the lens 
         %
         % - - Output - -
         % sensorPlaneRadiantPower : MxNx3 array of radiant power values after being affected by
         %                           lens and being received at the sensor plane
         
         
         % Unpack properties to local variables in correct form, which transforms radial distances 
         % from distorted -> undistorted
         distortionInverseCoeffs = invert_poly(obj.distortionCoeffs);
         rgInverseCoeffs = lca2inverse_poly(obj.lcaCoeffs_rg);
         bgInverseCoeffs = lca2inverse_poly(obj.lcaCoeffs_bg);
         
         width = size(sceneRadiantPower, 2);
         height = size(sceneRadiantPower, 1);
         
         % Produce a mesh grid of the coordinates of each pixel, relative to the exact center of the image
         xs = (1:width) - ((width+1)/2 + obj.opticalCenterOffset(1));
         ys = (1:height) - ((height+1)/2 + obj.opticalCenterOffset(2));
         [X, Y] = meshgrid(xs,ys);
         normFactor = sqrt(((width+1)/2)^2 + ((height+1)/2)^2); % to normalize center-corner distance to 1
         
         % Convert cartesian coordinates of each pixel location to polar
         [THETA, RHO_u] = cart2pol(X, Y);
         scaleFactor = polyval(distortionInverseCoeffs, 1); % to keep the corners pinned to the corners
         RHO_u = RHO_u/normFactor*scaleFactor;
         
         % Make a new radial component for each color channel. They all share the same overall
         % distortion, and then the red and blue channels are aberrated relative to the green.
         RHO_d = zeros(size(RHO_u,1),size(RHO_u,2),3);
         RHO_d(:,:,2) = polyval(distortionInverseCoeffs,RHO_u);
         RHO_d(:,:,1) = polyval(rgInverseCoeffs,RHO_d(:,:,2));
         RHO_d(:,:,3) = polyval(bgInverseCoeffs,RHO_d(:,:,2));
         
         % Re-sample at the new (distorted) coordinates by color channel.
         sensorPlaneRadiantPower = zeros(height,width,3);
         for c = 1:3
            channelData = double(sceneRadiantPower(:,:,c));
            % Convert back to cartesian coordinates to get the (x,y) distorted sample points
            % in image space
            [X_d, Y_d] = pol2cart(THETA, RHO_d(:,:,c)*normFactor);
            sensorPlaneRadiantPower(:,:,c) = interp2(X, Y, channelData, X_d, Y_d, 'cubic', 0);
            
            % Add flare, for now a field-wide constant per color channel
            meanFlare = obj.flareConstant*norm(channelData(:))/sqrt(width*height);
            sensorPlaneRadiantPower(:,:,c) = sensorPlaneRadiantPower(:,:,c)*(1-obj.flareConstant) + meanFlare;
         end
         
      end
   end
   
end % end classdef



% - - - Utility functions - - - 
function inverseCoeffs = lca2inverse_poly(lcaCoeffs)
% inverseCoeffs = lca2inverse_poly(lcaCoeffs)
%
% Converts polynomial coefficients from the form Imatest/CPIQ describes LCA in, which is based on
% relative radial displacement, to polynomial coefficients which directly map from distorted
% color channel radii to undistorted radii. 
%
% Does conversion numerically, so this is really only valid for functions which can be well
% appropximated by a 5th order (or lower) polynomial.
%
% Always returns a 5-th oder polynomial.

lcaCoeffs(end-1) = lcaCoeffs(end-1)+1;

rDistorted = linspace(0,1,50);
rUndistorted = polyval(lcaCoeffs,rDistorted);
inverseCoeffs = polyfit(rUndistorted,rDistorted,5);

end

function outcoeffs = invert_poly(inCoeffs)
% forwardCoeffs = invert_poly(inverseCoeffs)
% inverseCoeffs = invert_poly(forwardCoeffs)
%
% Inverts the polynomial whose coefficients are supplied.
% This function is only good for distortion/aberration which is well approximated by 5th order
% polynomial.
%
% Always puts out a 5th order inversion polynomial. Input can be 3rd or 5th order.


% Inversion is done numerically by generating some undistorted points, calculating some distorted
% version of them, and then fitting a polynomial.

rDistorted = linspace(0,1,10); % radial distortion is <= 5th order, so 10 points is more than enough
rUndistorted = polyval(inCoeffs,rDistorted);
outcoeffs = polyfit(rUndistorted,rDistorted,5);
end