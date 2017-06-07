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

classdef DummyBayerSensor < SensorModel
   % A dummy sensor which just passes through data. It does integerize the data and mosaic it with a
   % given Bayer CFA orientation, though. 
   
   methods
      
      function obj = DummyBayerSensor(sensorSize,varargin)
         if nargin==1
            varargin = {};
         end
         obj = obj@SensorModel(sensorSize,varargin{:});
       
      end
      
      
      function dn = expose(~,radiantPower,~)
         % dn = dummy.expose(radiantPower)
         %
         % Also accepts a second 't' argument to be consistent with other SensorModels, but simply
         % ignores it.
         
         dn = uint16(mosaic(radiantPower,obj.bayerPhase));
      end
   end
   
   
end % end classdef