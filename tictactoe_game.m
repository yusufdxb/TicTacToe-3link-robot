% tictactoe_game.m
% =========================================================
% TicTacToe Game Logic + Minimax AI
% =========================================================
% Board: 3x3 matrix. 0=empty, 1=human(X), 2=robot(O)
% Author: Yusuf Guenena
% =========================================================

function board = new_board()
    board = zeros(3,3);
end

function valid = is_valid_move(board, row, col)
    valid = (row>=1 && row<=3 && col>=1 && col<=3 && board(row,col)==0);
end

function board = apply_move(board, row, col, player)
    board(row,col) = player;
end

function result = check_winner(board)
    result = 0;
    for p=[1 2]
        for r=1:3, if all(board(r,:)==p), result=p; return; end; end
        for c=1:3, if all(board(:,c)==p), result=p; return; end; end
        if board(1,1)==p&&board(2,2)==p&&board(3,3)==p, result=p; return; end
        if board(1,3)==p&&board(2,2)==p&&board(3,1)==p, result=p; return; end
    end
    if all(board(:)~=0), result=3; end
end

function [row,col] = minimax_best_move(board)
    best=-Inf; row=-1; col=-1;
    for r=1:3
        for c=1:3
            if board(r,c)==0
                board(r,c)=2;
                s=minimax(board,false);
                board(r,c)=0;
                if s>best, best=s; row=r; col=c; end
            end
        end
    end
end

function score = minimax(board, isMax)
    r=check_winner(board);
    if r==2, score= 10; return; end
    if r==1, score=-10; return; end
    if r==3, score=  0; return; end
    if isMax
        best=-Inf;
        for i=1:3, for j=1:3
            if board(i,j)==0
                board(i,j)=2; best=max(best,minimax(board,false)); board(i,j)=0;
            end
        end; end
        score=best;
    else
        best=Inf;
        for i=1:3, for j=1:3
            if board(i,j)==0
                board(i,j)=1; best=min(best,minimax(board,true)); board(i,j)=0;
            end
        end; end
        score=best;
    end
end

function print_board(board)
    s={'.','X','O'};
    for r=1:3
        for c=1:3
            fprintf(' %s ',s{board(r,c)+1});
            if c<3, fprintf('|'); end
        end
        fprintf('\n');
        if r<3, fprintf('---|---|---\n'); end
    end
    fprintf('\n');
end
