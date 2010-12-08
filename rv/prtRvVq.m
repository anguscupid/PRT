classdef prtRvVq < prtRv
    % prtRvVq  Vector quantization random variable
    %   Vector quanitization uses k-means to discretize the data space
    %   using NCATEGORIES means. MEANS are the discrete points in space and
    %   have PROBABILITIES representing theirprominence in the data. The
    %   pdf is calculated by mapping to the nearest entry of the MEANS and
    %   giving the data point the corresponding entry in PROBABILITIIES.
    %
    %   RV = prtRvVq creates a prtRvVq object with empty means and
    %   probabilities. The MEANS and PROBABILITIES must be set either
    %   directly, or by calling the MLE method.
    %
    %   RV = prtRvVq(PROPERTY1, VALUE1,...) creates a prtRvVq object RV
    %   with properties as specified by PROPERTY/VALUE pairs.
    %
    %   A prtRvVq object inherits all properties from the prtRv class. In
    %   addition, it has the following properties:
    %
    %   nCategories   - The number of means that are calculated to
    %                   discretize the data
    %   means         - The means (calculated through k-means) that are
    %                   used to approximate the density
    %   probabilities - The probabilities of each of the means
    %   
    %  A prtRvVq object inherits all methods from the prtRv class. The MLE
    %  method can be used to estimate the distribution parameters from
    %  data.
    %
    %  Example:
    %
    %  dataSet = prtDataGenUnimodal;        % Load a dataset consisting of
    %                                       % 2 features
    %  dataSet = retainFeatures(dataSet,1); % Retain only the first feature
    %
    %  RV = prtRvVq;                        % Create a prtRvVq object
    %  RV = RV.mle(dataSet);                % Compute the VQ parameters
    %                                       % form the data
    %  RV.plotPdf                           % Plot the pdf
    %  
    %   See also: prtRv, prtRvMvn, prtRvGmm, prtRvMultinomial,
    %   prtRvUniform, prtRvUniformImproper
    
    properties (Dependent = true)
        probabilities
        means
        nCategories
    end
    
    properties (Dependent = true, Hidden=true)
        InternalKMeansPrototypes
        InternalDiscrete
        nDimensions
    end
    
    properties (SetAccess = 'private', GetAccess = 'private', Hidden=true)
        %InternalKMeansPrototypesDepHelp = prtClassKmeansPrototypes('kMeansHandleEmptyClusters','random');
        meanDepHelper = [];
        InternalDiscreteDepHelp = prtRvDiscrete();
        nCategoriesDepHelp = 2;
    end
    
    methods
        % The Constructor
        function R = prtRvVq(varargin)
            R.name = 'Vector Quantization Random Variable';
            
            R = constructorInputParse(R,varargin{:});
        end
        function val = get.means(R)
            val = R.meanDepHelper;
        end
        function val = get.probabilities(R)
            val = R.InternalDiscreteDepHelp.probabilities;
        end
        function val = get.nCategories(R)
            val = R.nCategoriesDepHelp;
        end
        
        function val = get.InternalDiscrete(R)
            val = R.InternalDiscreteDepHelp;
        end
        
        function R = set.InternalDiscrete(R,val)
            R.InternalDiscreteDepHelp = val;
        end
        
        function R = set.InternalDiscreteDepHelp(R,val)
            assert(isa(val,'prtRvDiscrete'),'InternalDiscrete must be a prtRvDiscrete.')
            R.InternalDiscreteDepHelp = val;
        end
        
        function R = set.nCategories(R,val)
            assert(numel(val)==1 && val==floor(val) && val > 0,'nCategories must be a scalar positive integer.');
            
            R.nCategoriesDepHelp = val;
        end
        
        function R = set.probabilities(R,val)
            assert(isnumeric(val) && isvector(val),'probabilities must be numer vector whose values sum to one.');
            
            if ~isempty(R.InternalDiscreteDepHelp.symbols)
                assert(size(R.InternalDiscreteDepHelp.symbols,1) == numel(val),'size mismatch between probabilities and means.')
            end
            R.InternalDiscreteDepHelp.probabilities = val(:);
        end
        
        function R = set.means(R,val)
            assert(ndims(val)==2 && isnumeric(val),'means must be a 2D numeric matrix.')
            
            if ~isempty(R.InternalDiscreteDepHelp.probabilities)
                assert(numel(R.InternalDiscreteDepHelp.probabilities) == size(val,1),'probabilities indicate that %d means of arbitrary dimension are required, but %d means of dimensionality %d were provided',length(R.InternalDiscreteDepHelp.probabilities),size(val,1),size(val,2));
            end
            
            R.InternalDiscrete.symbols = val;
            R.meanDepHelper = val;
        end

        function val = get.nDimensions(R)
            if ~isempty(R.means)
                val = size(R.means,2);
            else
                val = [];
            end
        end
        
        function R = mle(R,X)
            X = R.dataInputParse(X); % Basic error checking etc
            assert(isnumeric(X) && ndims(X)==2,'X must be a 2D numeric array.');
            
            R.means = prtUtilKmeans(X,R.nCategories,'handleEmptyClusters','random');
            
            trainingOutput = R.data2ClosestMeanInd(X);
            
            R.InternalDiscrete = prtRvDiscrete('symbols',R.means,'probabilities',histc(trainingOutput,1:R.nCategories)/size(X,1));
        end
        
        function vals = pdf(R,X)
            [isValid, reasonStr] = R.isValid;
            assert(isValid,'PDF cannot yet be evaluated. This RV is not yet valid %s.',reasonStr);
            
            X = R.dataInputParse(X); % Basic error checking etc
            assert(size(X,2) == R.nDimensions,'Data, RV dimensionality missmatch. Input data, X, has dimensionality %d and this RV has dimensionality %d.', size(X,2), R.nDimensions)
            assert(isnumeric(X) && ndims(X)==2,'X must be a 2D numeric array.');
            
            trainingOutput = R.data2ClosestMeanInd(X);
            vals = R.probabilities(trainingOutput);
            vals = vals(:);
        end
        
        function vals = logPdf(R,X)
            [isValid, reasonStr] = R.isValid;
            assert(isValid,'LOGPDF cannot yet be evaluated. This RV is not yet valid %s.',reasonStr);
            
            vals = log(pdf(R,X));
        end
        
        function vals = draw(R,N)
            if nargin < 2 || isempty(N)
                N = 1;
            end
            
            [isValid, reasonStr] = R.isValid;
            assert(isValid,'DRAW cannot yet be evaluated. This RV is not yet valid %s.',reasonStr);
            
            assert(numel(N)==1 && N==floor(N) && N > 0,'N must be a positive integer scalar.')
            
            vals = R.InternalDiscrete.draw(N);
        end

        function varargout = plotPdf(R,varargin)
            h = plotPdf(R.InternalDiscrete);
            
            varargout = {};
            if nargout
                varargout = {h};
            end
        end
        
        function varargout = plotCdf(R,varargin)
            h = plotCdf(R.InternalDiscrete);
            
            varargout = {};
            if nargout
                varargout = {h};
            end
        end        
        
        function quantizedData = vq(R,X)
            X = R.dataInputParse(X); % Basic error checking etc
            quantizedData = data2ClosestMeanInd(R,X);
        end
    end
    
    methods (Hidden = true)
        function [val, reasonStr] = isValid(R)
            if numel(R) > 1
                val = false(size(R));
                for iR = 1:numel(R)
                    [val(iR), reasonStr] = isValid(R(iR));
                end
                return
            end
            
            [val, reasonStr] = isValid(R.InternalDiscrete);
            reasonStr = strrep(reasonStr,'symbols','means');
        end
        
        function val = plotLimits(R)
            val = plotLimits(R.InternalDiscrete);
        end

        function val = isPlottable(R)
            val = isPlottable(R.InternalDiscrete);
        end
    end
    
    methods (Hidden = true, Access=protected)
        function closestMeanInds = data2ClosestMeanInd(R,X)
            distance = prtDistanceEuclidean(X,R.means);
            [dontNeed, closestMeanInds] = min(distance,[],2); %#ok<ASGLU>
        end
    end
    
end