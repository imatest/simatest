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

classdef DummyLens < LensModel
   % A dummy lens which just passes through exactly the input data.
   
   
   methods
      
      % Override the simulate method to accomplish the bypass.
      function processedIm = simulate(~,scene)
         % processedIm = dummy.simulate(scene)    

         processedIm = double(scene); % needs to return real values, as per superclass' contract
      end
      
   end
   
   
end % end classdef