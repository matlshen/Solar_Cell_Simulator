%% Module Class
% Defines a group of series connected solar cells with bypass diode in
% parallel (modelled as ideal diode)

classdef Module < handle

    properties
        id                      % Module identifier
        cellList SolarCell      % Vector containing SolarCell objects
        numCells                % Number of objects in CellList
        shadeList               % Vector containing cell shade levels
        bypassPresent           % 1 if there is a bypass diode present
    end

    methods

        % Appends cell to end of cellList
        function AddCell(obj, cell)
            obj.numCells = obj.numCells + 1;
            obj.cellList(obj.numCells) = cell;
        end

        % Remove cell from end of cellList
        function RemoveCell(obj, idx)
            obj.cellList(idx) = [];
            obj.numCells = obj.numCells - 1;
        end
    end

    methods (Static)

        % Constructor function
        function obj = CreateModule(id, varargin)
            obj = Module;
            obj.id = id;
            obj.numCells = nargin - 1;
            obj.shadeList = [];
            obj.bypassPresent = 0;
            for i = 1:(nargin - 1)
                obj.cellList(i) = varargin{i};
            end
        end

    end

end