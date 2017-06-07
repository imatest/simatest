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

classdef SensorModel
   % The SensorModel class represents a linear photosensor array with a realistic noise model (as
   % per EMVA1288 and other "linear sensor" sources). Its various instance properties represent
   % parameters of the noise model which can be set by the user. 
   %
   % Its main function is to simulate an exposure when given an input array that represents the
   % radiant power density at each location of the sensor array via the .expose() method.
   %
   % The sensor is modeled as having a Bayer mosaic pattern (user's choice of orientation), but this
   % is currently implemented by simply re-mosaicking (i.e., throwing away most of) the 3-channel
   % input radiant-power array. Scaling of the different color channels by different amounts is 
   % achieved only by different per-channel QE values, which turns that parameter effectively into 
   % meaning "the relative sensitivity of this channel to the light of that channel after
   % filtering."
   % 
   %
   % Note: output data type of this is always uint16, even if the sensor being modeled is
   % effectively smaller bit-depth than this. The effective bit-depth of the sensor is controlled by
   % setting the .maxDN property.
   %
   % 
   % Notes about noise model elements:
   % - .noiseFloor_e combines any and all additive white noise sources (whether from readout noise, 
   %        amplifier noise, whatever) and expresses this in terms of effective electrons-worth of 
   %        noise at the photodetector. This can be related back to "scene referred noise" (rather,
   %        the lambda parameter of the Poisson distribution of effective scene-referred noise) by:
   %              lambda_scene = noiseFloor_e/(qe * t)
   % - Though the black level offset is typically physically implemented as a bias voltage, we only
   %        care about its value in DN here.
   % - Refer to EMVA1288 for further understanding of noise model elements
   %
   %
   % See also: DummyBayerSensor, DummyColorSensor
   %
   % TODO: .offset could be pixel-, column-, and/or row-wise
   
   properties
      % These three properties need to be set at time of construction because they require knowledge
      % of the input 'scene' size.
      arraySize                     % i.e., MxN
      prnu                          % MxN, default all ones (set in constructor)
      darkCurrent                   % MxN, in electrons per second, default all zeros
      
      noiseFloor_e   = 0;           % scalar or size arraySize, units of electrons 
      qe             = [1, 1, 1];   % units of electrons/photons, order of [R, G, B] 
      gain           = 1;           % linear system gain, units of DN/e
      offset         = 0;           % black-level offset, units of DN. 
      wellCapacity   = inf;         % units of electrons
      maxDN          = 2^10-1;      % units of DN
      
      bayerPhase     = 'grbg'
   end
   
    
   
   methods
      
      function obj = SensorModel(sensorSize,varargin)
         % model = SensorModel(sensorSize)
         % model = SensorModel(sensorSize, 'prnu',...,'darkCurrent',...)
         %
         % Create a SensorModel based on a given number of pixels (sensorSize). 
         % Optional construction name/value parameters 'prnu' and 'darkCurrent' are allowed, whos
         % arguments must be 1-channel matrices the same size as sensorSize.
         %
         % The default SensorModel is 10-bit Bayer-GRBG, unitary gain and qe, infinite well capacity
         % and no data offset, and no additive noise, PRNU, or dark current.
         
         % Parse inputs
         parser = inputParser();
         default_prnu = ones(sensorSize);
         default_darkCurrent = zeros(sensorSize);
         parser.addParameter('prnu',default_prnu)
         parser.addParameter('darkCurrent',default_darkCurrent)
         parser.parse(varargin{:});
         params = parser.Results;
         
         obj.arraySize = sensorSize;
         obj.prnu = params.prnu;
         obj.darkCurrent = params.darkCurrent;
        
      end
      
      
      function dn = expose(obj,radiantPower,t)
         % dn = model.expose(radiantPower, t)
         %
         % Simulate an exposure of a scene on this sensor.
         %
         % - - Inputs - - 
         % radiantPower : MxNx3 array (same M,N as model.arraySize) of real values indicating the 
         %                 radiant power at the sensor plane at each pixel location units of photons
         %                 per second. 
         % t : exposure time in seconds
         % 
         % - - Output - -
         % dn : integer data array, as if straight out of the ADC
         
         % - - Simulate color filter array - -
         qe_mask = repmat(reshape(obj.qe,[1,1,size(radiantPower,3)]),size(radiantPower,1),size(radiantPower,2));
         filteredPower = qe_mask.*radiantPower;
         mosaickedPower = mosaic(filteredPower,obj.bayerPhase); 
         
         % - - Simulate the number of electrons in the well - - 
         % Note: '*/ 10^-12' because of how imnoise() deals with doubles.
         poisson_base = (mosaickedPower+obj.darkCurrent)*t + obj.noiseFloor_e;
         e = imnoise(poisson_base*10^-12,'poisson'); 
         e = min(e*10^12, obj.wellCapacity);
         
         % - - Conversion of electrons to voltage - -
         v = (obj.gain * e .* obj.prnu) + obj.offset;
         
         % - - Simulate analog-digital-conversion - -
         dn = min(uint16(v),obj.maxDN);
         
      end
      
   end % end methods
   
end % end classdef


% - - Utility function - -
function cfa = mosaic(fullColorIm,phase)
% cfa = mosaic(fullColorIm,phase)
%
% Convert an MxNx3 RGB image data array into a Bayer color-filter-array image.

[M,N,~] = size(fullColorIm);
rmask = zeros(M,N);
bmask = zeros(M,N);

switch phase
   case 'grbg'
      rmask(1:2:end,2:2:end)= 1;
      bmask(2:2:end,1:2:end)= 1;
   case 'bggr'
      rmask(2:2:end,2:2:end)= 1;
      bmask(1:2:end,1:2:end)= 1;
   case 'rggb'
      rmask(1:2:end,1:2:end)= 1;
      bmask(2:2:end,2:2:end)= 1;
   case 'gbrg'
      rmask(2:2:end,1:2:end)= 1;
      bmask(1:2:end,2:2:end)= 1;
   otherwise
      error(['Incorrect mosaic phase argument. ',...
         'Must be one of ''grbg'', ''bggr'', ''rggb'', or ''gbrg''.'])
end

gmask = double(~(rmask | bmask)); % double to use as multiplier, not index

cfa = fullColorIm(:,:,1).*rmask + fullColorIm(:,:,2).*gmask + fullColorIm(:,:,3).*bmask;

end % end function