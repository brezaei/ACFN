%
%  Attentional Correlation Filter Network for Adaptive Visual Tracking
%
%  Jongwon Choi, 2017
%  https://sites.google.com/site/jwchoivision/  
% 
%  Additional function for 'imresize' in MATLAB
%  Keep memory of the re-estimated parts for sequential images.
% 
%  MATLAB code for correlation filter network
%  When you use this code for your research, please refer the below references.
%  You can't use this code for any commercial purpose without author's
%  agreement.
%  If you have any question or comment, please contact to
%  jwchoi.pil@gmail.com.
%  
% 
%
%  Reference:
%  [1] J. Choi, et al., "Attentional Correlation Filter Network for Adaptive Visual Tracking", CVPR2017
%  [2] J. Choi, et al., "Visual Tracking Using Attention-Modulated Disintegration and Integration", CVPR2016


function [resized_im, ws, idxs] = imresize_mem(im, window_sz, ws, idxs)

if(size(im,1)==window_sz(1) && size(im,2)==window_sz(2))
    
    resized_im = im;
    ws = [];
    idxs = [];
    
else

    if(isempty(ws) || isempty(idxs))
        ws = cell(1,2);
        idxs = cell(1,2);
        for k = 1:2
            [ws{k}, idxs{k}] = contributions(size(im, k), ...
                window_sz(k), window_sz(k)/size(im, k), @cubic, ...
                4, 1);
        end
    end

    order = find(window_sz./size(im(:,:,1)) ~= 1);
    B = im;
    for k = 1:numel(order)
        dim = order(k);
        B = resizeAlongDim(B, dim, ws{dim}, idxs{dim});
    end

    resized_im = B;
    
end


%=====================================================================
function [weights, indices] = contributions(in_length, out_length, ...
                                            scale, kernel, ...
                                            kernel_width, antialiasing)


if (scale < 1) && (antialiasing)
    % Use a modified kernel to simultaneously interpolate and
    % antialias.
    h = @(x) scale * kernel(scale * x);
    kernel_width = kernel_width / scale;
else
    % No antialiasing; use unmodified kernel.
    h = kernel;
end

% Output-space coordinates.
x = (1:out_length)';

% Input-space coordinates. Calculate the inverse mapping such that 0.5
% in output space maps to 0.5 in input space, and 0.5+scale in output
% space maps to 1.5 in input space.
u = x/scale + 0.5 * (1 - 1/scale);

% What is the left-most pixel that can be involved in the computation?
left = floor(u - kernel_width/2);

% What is the maximum number of pixels that can be involved in the
% computation?  Note: it's OK to use an extra pixel here; if the
% corresponding weights are all zero, it will be eliminated at the end
% of this function.
P = ceil(kernel_width) + 2;

% The indices of the input pixels involved in computing the k-th output
% pixel are in row k of the indices matrix.
indices = bsxfun(@plus, left, 0:P-1);

% The weights used to compute the k-th output pixel are in row k of the
% weights matrix.
weights = h(bsxfun(@minus, u, indices));

% Normalize the weights matrix so that each row sums to 1.
weights = bsxfun(@rdivide, weights, sum(weights, 2));

% Mirror out-of-bounds indices; equivalent of doing symmetric padding
aux = [1:in_length,in_length:-1:1];
indices = aux(mod(indices-1,length(aux)) + 1);

% If a column in weights is all zero, get rid of it.
kill = find(~any(weights, 1));
if ~isempty(kill)
    weights(:,kill) = [];
    indices(:,kill) = [];
end

%---------------------------------------------------------------------

%=====================================================================
function f = cubic(x)
% See Keys, "Cubic Convolution Interpolation for Digital Image
% Processing," IEEE Transactions on Acoustics, Speech, and Signal
% Processing, Vol. ASSP-29, No. 6, December 1981, p. 1155.

absx = abs(x);
absx2 = absx.^2;
absx3 = absx.^3;

f = (1.5*absx3 - 2.5*absx2 + 1) .* (absx <= 1) + ...
                (-0.5*absx3 + 2.5*absx2 - 4*absx + 2) .* ...
                ((1 < absx) & (absx <= 2));
%---------------------------------------------------------------------

%=====================================================================
function f = triangle(x)
f = (x+1) .* ((-1 <= x) & (x < 0)) + (1-x) .* ((0 <= x) & (x <= 1));
%---------------------------------------------------------------------

%=====================================================================
function out = resizeAlongDim(in, dim, weights, indices)
% Resize along a specified dimension
%
% in           - input array to be resized
% dim          - dimension along which to resize
% weights      - weight matrix; row k is weights for k-th output pixel
% indices      - indices matrix; row k is indices for k-th output pixel

out_length = size(weights, 1);

size_in = size(in);
size_in((end + 1) : dim) = 1;

if (ndims(in) > 3)
    % Reshape in to be a three-dimensional array.  The size of this
    % three-dimensional array is the variable pseudo_size_in below.
    %
    % Final output will be consistent with the original input.
    pseudo_size_in = [size_in(1:2) prod(size_in(3:end))];
    in = reshape(in, pseudo_size_in);
end

% The 'out' will be uint8 if 'in' is logical 
% Otherwise 'out' datatype will be same as 'in' datatype
out = imresizemex(in, weights', indices', dim);

if ( (length(size_in) > 3) && (size_in(end) > 1) )
    % Restoring final output to expected size
    size_out = size_in;
    size_out(dim) = out_length;
    out = reshape(out, size_out);
end
%---------------------------------------------------------------------